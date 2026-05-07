# =========================================================
# Strict MFPCA workflow for aquaculture water-quality monitoring
# Cleaned and reorganized - runs top to bottom without errors
# =========================================================

suppressPackageStartupMessages({
  library(ggplot2)
  library(ggrepel)
  library(dplyr)
  library(tidyr)
  library(sp)
  library(gstat)
  library(viridis)
  library(MFPCA)
  library(funData)
})

options(stringsAsFactors = FALSE, scipen = 999)
set.seed(123)

# =========================================================
# SECTION 1. Helper functions (used throughout)
# =========================================================

print_section <- function(title) {
  cat("\n", paste(rep("=", 90), collapse = ""), "\n", sep = "")
  cat(title, "\n")
  cat(paste(rep("=", 90), collapse = ""), "\n", sep = "")
}

safe_min  <- function(x) if (all(is.na(x))) NA_real_ else min(x, na.rm = TRUE)
safe_max  <- function(x) if (all(is.na(x))) NA_real_ else max(x, na.rm = TRUE)
safe_mean <- function(x) if (all(is.na(x))) NA_real_ else mean(x, na.rm = TRUE)
safe_sd   <- function(x) if (sum(!is.na(x)) <= 1) NA_real_ else sd(x, na.rm = TRUE)

safe_label <- function(x) {
  x <- as.character(x)
  x <- trimws(x)
  x[x == ""] <- "<blank>"
  out <- iconv(x, from = "", to = "UTF-8", sub = "byte")
  ifelse(is.na(out), x, out)
}

print_character_vector <- function(x) {
  x2 <- safe_label(x)
  cat(paste0("- ", x2, collapse = "\n"), "\n")
}

extract_surface <- function(fun_obj_single) {
  x  <- fun_obj_single@X
  dx <- dim(x)
  if (length(dx) == 3) return(x[1, , ])
  if (length(dx) == 2) return(x)
  stop("无法识别 funData 对象的维度结构。")
}

write_csv_utf8 <- function(df, file) {
  write.csv(df, file = file, row.names = FALSE, fileEncoding = "UTF-8")
}

save_plot_gg <- function(p, file, width = 8, height = 6) {
  ggsave(filename = file, plot = p, width = width, height = height, dpi = 300)
}

# 抽稀海岸线段（Step F 与小图共用）
thin_segment <- function(dat, max_points = 3000) {
  n <- nrow(dat)
  if (n <= max_points) return(dat)
  idx <- unique(round(seq(1, n, length.out = max_points)))
  dat[idx, , drop = FALSE]
}

# 将开放岸线段沿西侧边界闭合（用于 pip 判断和矢量填充）
close_segment_land_side <- function(seg_lon, seg_lat,
                                    xmin, xmax, ymin, ymax) {
  n   <- length(seg_lon)
  gap <- sqrt((seg_lon[1]-seg_lon[n])^2 + (seg_lat[1]-seg_lat[n])^2)
  if (gap < 0.3) return(list(lon = seg_lon, lat = seg_lat))
  if (seg_lat[n] < seg_lat[1]) {
    extra_lon <- c(xmin, xmin);  extra_lat <- c(ymin, ymax)
  } else {
    extra_lon <- c(xmin, xmin);  extra_lat <- c(ymax, ymin)
  }
  list(lon = c(seg_lon, extra_lon, seg_lon[1]),
       lat = c(seg_lat, extra_lat, seg_lat[1]))
}

# 根据数据宽高比反推 PDF 高度，消除 asp=1 留白
compute_pdf_h <- function(w, mar, xr, yr, lines_per_inch = 0.20) {
  uw <- w - (mar[2] + mar[4]) * lines_per_inch
  uw * (yr / xr) + (mar[1] + mar[3]) * lines_per_inch
}

# =========================================================
# SECTION 2. Output directory & logging
# =========================================================

out_dir  <- "mfpca_outputs"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

log_file <- file.path(out_dir, "analysis_log.txt")
log_con  <- file(log_file, open = "wt", encoding = "UTF-8")
sink(log_con, split = TRUE)
sink(log_con, type = "message")

on.exit({
  try(sink(type = "message"), silent = TRUE)
  try(sink(), silent = TRUE)
  try(close(log_con), silent = TRUE)
}, add = TRUE)

print_section("Strict MFPCA 分析开始")

# =========================================================
# SECTION 3. Data loading and screening
# =========================================================

print_section("Step 0. 数据读取与变量筛选")

input_file <- if (file.exists("surface_data_new_nodof.csv"))
  "surface_data_new_nodof.csv" else "surface_data.csv"
cat("输入文件：", input_file, "\n")

df_raw <- read.csv(input_file, check.names = FALSE, fileEncoding = "GB18030")
cat("原始数据维度：", nrow(df_raw), "行 x", ncol(df_raw), "列\n")

if (!all(c("经度", "纬度") %in% colnames(df_raw)))
  stop("数据中未找到'经度'或'纬度'列，请检查表头。")

candidate_var_names   <- colnames(df_raw)[3:ncol(df_raw)]
is_numeric_var        <- sapply(df_raw[, candidate_var_names, drop = FALSE], is.numeric)
numeric_var_names     <- candidate_var_names[is_numeric_var]
non_numeric_var_names <- candidate_var_names[!is_numeric_var]

cat("数值变量数：", length(numeric_var_names), "\n")
if (length(non_numeric_var_names) > 0) {
  cat("以下非数值变量已自动剔除：\n")
  print_character_vector(non_numeric_var_names)
}

df <- df_raw %>%
  rename(longitude = `经度`, latitude = `纬度`) %>%
  select(longitude, latitude, all_of(numeric_var_names)) %>%
  mutate(sep_row = is.na(longitude) | is.na(latitude),
         time_id = cumsum(sep_row) + 1) %>%
  filter(!sep_row) %>%
  select(-sep_row)

time_counts <- df %>% count(time_id, name = "n_points")
cat("各时间点样本数：\n"); print(time_counts)
if (nrow(time_counts) < 2) stop("有效时间点少于 2 个，无法进行 MFPCA。")

all_na_vars <- numeric_var_names[
  sapply(df[, numeric_var_names, drop = FALSE], function(x) all(is.na(x)))]
if (length(all_na_vars) > 0) {
  cat("以下全 NA 变量已自动剔除：\n")
  print_character_vector(all_na_vars)
}
numeric_var_names <- setdiff(numeric_var_names, all_na_vars)
if (length(numeric_var_names) == 0) stop("没有可用于分析的数值变量。")

valid_var_names <- c(); invalid_var_names <- c()
for (v in numeric_var_names) {
  n_by_time <- df %>% group_by(time_id) %>%
    summarise(n_valid = sum(!is.na(.data[[v]])), .groups = "drop")
  if (all(n_by_time$n_valid >= 2))
    valid_var_names <- c(valid_var_names, v)
  else
    invalid_var_names <- c(invalid_var_names, v)
}
if (length(invalid_var_names) > 0) {
  cat("以下变量因某时间点有效观测数 < 2，已剔除：\n")
  print_character_vector(invalid_var_names)
}
if (length(valid_var_names) == 0)
  stop("没有变量满足每时间点至少 2 个有效观测值。")

df <- df %>% select(longitude, latitude, time_id, all_of(valid_var_names))

orig_var_names  <- valid_var_names
num_vars        <- length(orig_var_names)
clean_var_names <- paste0("Var", seq_len(num_vars))
var_lookup      <- tibble(clean_name = clean_var_names,
                          original_name = orig_var_names)
colnames(df)[match(orig_var_names, colnames(df))] <- clean_var_names

cat("最终纳入插值流程的变量数：", num_vars, "\n")
print(var_lookup, n = nrow(var_lookup))

missingness_by_time_variable <- df %>%
  select(time_id, all_of(clean_var_names)) %>%
  pivot_longer(cols = -time_id, names_to = "variable", values_to = "value") %>%
  group_by(time_id, variable) %>%
  summarise(
    n_total       = n(),
    n_valid       = sum(!is.na(value)),
    n_missing     = sum(is.na(value)),
    valid_ratio   = n_valid / n_total,
    missing_ratio = n_missing / n_total,
    .groups = "drop"
  ) %>%
  left_join(var_lookup, by = c("variable" = "clean_name"))

write_csv_utf8(time_counts,
               file.path(out_dir, "01_time_counts.csv"))
write_csv_utf8(missingness_by_time_variable,
               file.path(out_dir, "02_missingness_by_time_variable.csv"))
write_csv_utf8(var_lookup,
               file.path(out_dir, "07_variable_lookup_final.csv"))

# =========================================================
# SECTION 4. Common spatial grid
# =========================================================

print_section("Step 1. 构造统一空间网格")

x_min <- min(df$longitude, na.rm = TRUE) - 0.01
x_max <- max(df$longitude, na.rm = TRUE) + 0.01
y_min <- min(df$latitude,  na.rm = TRUE) - 0.01
y_max <- max(df$latitude,  na.rm = TRUE) + 0.01

num_interpolation <- 400
grd_df <- expand.grid(
  longitude = seq(x_min, x_max, length.out = num_interpolation),
  latitude  = seq(y_min, y_max, length.out = num_interpolation)
) %>% mutate(grid_id = row_number())

grd_sp <- grd_df[, c("longitude", "latitude")]
coordinates(grd_sp) <- ~longitude + latitude
gridded(grd_sp) <- TRUE
cat(num_interpolation, "×", num_interpolation, "spatial grid created.\n")

# =========================================================
# SECTION 5. Spatial interpolation (IDW)
# =========================================================

print_section("Step 2. 逐时间点、逐变量空间插值")

interpolated_results_list <- list()
time_ids <- sort(unique(df$time_id))

for (t in time_ids) {
  d_time <- df %>% filter(time_id == t)
  for (v in seq_len(num_vars)) {
    clean_var_name    <- clean_var_names[v]
    original_var_name <- orig_var_names[v]
    d_time_var <- d_time %>%
      select(longitude, latitude, all_of(clean_var_name)) %>%
      filter(!is.na(.data[[clean_var_name]]))
    if (nrow(d_time_var) > 1) {
      coordinates(d_time_var) <- ~longitude + latitude
      idw_result <- suppressMessages(
        idw(formula   = as.formula(paste(clean_var_name, "~ 1")),
            locations = d_time_var,
            newdata   = grd_sp,
            idp       = 2.0)
      )
      idw_df <- as.data.frame(idw_result) %>%
        select(longitude, latitude, interpolated_value = var1.pred) %>%
        left_join(grd_df, by = c("longitude", "latitude")) %>%
        arrange(grid_id) %>%
        mutate(time_id = t, variable = clean_var_name,
               original_variable_name = original_var_name)
      interpolated_results_list[[paste(t, v, sep = "_")]] <- idw_df
    }
  }
  cat("Interpolation complete for Time ID:", t, "\n")
}

interpolated_df_raw <- bind_rows(interpolated_results_list)
if (nrow(interpolated_df_raw) == 0) stop("插值结果为空。")

expected_grid_n <- nrow(grd_df)
combo_check <- interpolated_df_raw %>%
  group_by(time_id, variable, original_variable_name) %>%
  summarise(n_grid = n(), .groups = "drop")

bad_combo <- combo_check %>% filter(n_grid != expected_grid_n)
if (nrow(bad_combo) > 0) {
  cat("以下 time-variable 组合插值网格不完整，已剔除：\n"); print(bad_combo)
  good_combo <- combo_check %>% filter(n_grid == expected_grid_n) %>%
    select(time_id, variable)
  interpolated_df_raw <- interpolated_df_raw %>%
    inner_join(good_combo, by = c("time_id", "variable"))
}

complete_vars <- interpolated_df_raw %>%
  distinct(time_id, variable) %>%
  count(variable, name = "n_time") %>%
  filter(n_time == length(time_ids)) %>%
  pull(variable)

interpolated_df_clean <- interpolated_df_raw %>% filter(variable %in% complete_vars)
if (length(complete_vars) == 0)
  stop("没有变量在所有时间点都成功完成插值。")

var_lookup_final     <- var_lookup %>% filter(clean_name %in% complete_vars)
variables            <- var_lookup_final$clean_name
orig_var_names_final <- var_lookup_final$original_name
time_points          <- sort(unique(interpolated_df_clean$time_id))

cat("最终进入 MFPCA 的变量数：", length(variables), "\n")
print(var_lookup_final, n = nrow(var_lookup_final))

# =========================================================
# SECTION 6. Standardization & MFPCA
# =========================================================

print_section("Step 3. 标准化并构建 MFPCA 输入对象")

lon_seq    <- sort(unique(interpolated_df_clean$longitude))
lat_seq    <- sort(unique(interpolated_df_clean$latitude))
argvals_2d <- list(longitude = lon_seq, latitude = lat_seq)
stopifnot(length(lon_seq) == num_interpolation,
          length(lat_seq) == num_interpolation)

fun_data_list           <- list()
standardized_array_list <- list()
standardization_summary <- list()

for (i_var in seq_along(variables)) {
  var           <- variables[i_var]
  original_name <- orig_var_names_final[i_var]
  df_var        <- interpolated_df_clean %>% filter(variable == var)
  
  mean_var <- mean(df_var$interpolated_value, na.rm = TRUE)
  sd_var   <- sd(df_var$interpolated_value,   na.rm = TRUE)
  if (is.na(sd_var) || sd_var < 1e-12) sd_var <- 1
  
  X_array <- array(NA_real_,
                   dim = c(length(time_points),
                           num_interpolation, num_interpolation))
  
  for (i in seq_along(time_points)) {
    df_time <- df_var %>% filter(time_id == time_points[i]) %>%
      arrange(longitude, latitude)
    if (nrow(df_time) != expected_grid_n)
      stop(paste0("变量 ", original_name, " 在 time_id=",
                  time_points[i], " 的网格不完整。"))
    X_array[i, , ] <- matrix(
      (df_time$interpolated_value - mean_var) / sd_var,
      nrow = num_interpolation, ncol = num_interpolation, byrow = FALSE)
  }
  
  standardized_array_list[[var]] <- X_array
  fun_data_list[[var]]           <- funData(argvals = argvals_2d, X = X_array)
  standardization_summary[[var]] <- tibble(
    variable                        = var,
    original_variable_name          = original_name,
    mean_before_standardization     = mean_var,
    sd_before_standardization       = sd_var,
    global_mean_after_standardization = safe_mean(as.vector(X_array)),
    global_sd_after_standardization   = safe_sd(as.vector(X_array))
  )
}

write_csv_utf8(bind_rows(standardization_summary),
               file.path(out_dir, "08_standardization_summary.csv"))

mfd_data     <- multiFunData(fun_data_list)
n_components <- length(mfd_data)
M_use        <- min(3, length(time_points) - 1)
if (M_use < 1) stop("可提取主成分数 < 1。")
cat("MFPCA 主成分数 M =", M_use, "\n")

mfpca_result <- MFPCA(
  mFData        = mfd_data,
  M             = M_use,
  uniExpansions = replicate(n_components,
                            list(type = "splines2D", k = 10),
                            simplify = FALSE)
)

# =========================================================
# SECTION 7. Core outputs: eigenvalues, scores, basic plots
# =========================================================

print_section("Step 4. MFPCA 核心结果输出")

eigenvalues <- as.numeric(mfpca_result$values)
prop_each   <- eigenvalues / sum(eigenvalues)
cum_prop    <- cumsum(prop_each)

eigen_table <- tibble(
  PC           = paste0("PC", seq_along(eigenvalues)),
  eigenvalue   = eigenvalues,
  prop_var     = prop_each,
  cum_prop_var = cum_prop
)
cat("Cumulative proportion of variance explained:\n"); print(cum_prop)
write_csv_utf8(eigen_table, file.path(out_dir, "11_eigenvalues.csv"))

pdf(file.path(out_dir, "eigenvalues_plot.pdf"), width = 8, height = 6)
plot(eigenvalues, type = "b", main = "Eigenvalues of MFPCA",
     xlab = "Component", ylab = "Variance")
dev.off()

scores <- as.matrix(mfpca_result$scores)
if (is.null(dim(scores))) scores <- matrix(scores, ncol = 1)
colnames(scores) <- paste0("PC", seq_len(ncol(scores)))
scores_df <- as.data.frame(scores) %>% mutate(time_id = time_points, .before = 1)
write_csv_utf8(scores_df, file.path(out_dir, "12_scores.csv"))

pdf(file.path(out_dir, "scores_plot.pdf"), width = 8, height = 6)
if (ncol(scores) >= 2) {
  plot(scores[,1], scores[,2], pch = 19,
       xlab = "PC1 Score", ylab = "PC2 Score",
       main = "MFPCA Scores (PC1 vs PC2)")
  text(scores[,1], scores[,2], labels = time_points, pos = 3)
} else {
  plot.new(); text(0.5, 0.5, "Only 1 principal component available.")
}
dev.off()

pdf(file.path(out_dir, "scores_time_plot.pdf"), width = 8, height = 6)
plot(time_points, scores[,1], type = "b",
     xlab = "Time", ylab = "PC1 Score", main = "PC1 Scores Over Time")
dev.off()

# =========================================================
# SECTION 8. RMSE by truncation level
# =========================================================

print_section("Step 5. 不同截断维数下的重构误差")

mean_surfaces <- vector("list", length(variables))
names(mean_surfaces) <- variables
for (j in seq_along(variables))
  mean_surfaces[[variables[j]]] <- apply(
    standardized_array_list[[variables[j]]], c(2,3), mean, na.rm = TRUE)

rmse_overall_list <- list()
for (M in seq_len(M_use)) {
  sse_all <- 0; n_all <- 0
  for (j in seq_along(variables)) {
    obs_array    <- standardized_array_list[[variables[j]]]
    mean_surface <- mean_surfaces[[variables[j]]]
    for (i in seq_along(time_points)) {
      recon <- mean_surface
      for (m in seq_len(M)) {
        phi_m <- extract_surface(mfpca_result$functions[[j]][m])
        recon <- recon + scores[i, m] * phi_m
      }
      diff_mat <- obs_array[i, , ] - recon
      sse_all  <- sse_all + sum(diff_mat^2, na.rm = TRUE)
      n_all    <- n_all   + sum(!is.na(diff_mat))
    }
  }
  rmse_overall_list[[paste0("M", M)]] <- tibble(M = M, RMSE = sqrt(sse_all / n_all))
}
rmse_overall_df <- bind_rows(rmse_overall_list)
write_csv_utf8(rmse_overall_df, file.path(out_dir, "15_rmse_by_M.csv"))
print(rmse_overall_df)

# =========================================================
# SECTION 9. PC contribution summary (top-5 + full ranking)
# =========================================================

print_section("Step 6. 各 PC 的主要贡献变量")

pc_var_contrib <- list()
for (pc in seq_len(M_use)) {
  for (j in seq_along(variables)) {
    phi      <- extract_surface(mfpca_result$functions[[j]][pc])
    energy_j <- mean(phi^2, na.rm = TRUE)
    pc_var_contrib[[paste0("PC", pc, "_", variables[j])]] <- tibble(
      PC = paste0("PC", pc), variable = variables[j],
      original_variable_name = orig_var_names_final[j], energy = energy_j
    )
  }
}
pc_var_contrib_full <- bind_rows(pc_var_contrib) %>%
  group_by(PC) %>%
  mutate(relative_energy = energy / sum(energy, na.rm = TRUE),
         rank_within_pc  = rank(-relative_energy, ties.method = "first")) %>%
  ungroup() %>% arrange(PC, rank_within_pc)

pc_var_contrib_top <- pc_var_contrib_full %>%
  group_by(PC) %>% slice_head(n = 5) %>% ungroup()

write_csv_utf8(pc_var_contrib_top,
               file.path(out_dir, "19_pc_variable_contribution_top.csv"))
write_csv_utf8(pc_var_contrib_full,
               file.path(out_dir, "19b_pc_variable_contribution_full.csv"))
print(pc_var_contrib_top)

# =========================================================
# SECTION 10. PC1 warning plots (threshold + EWMA)
# =========================================================

print_section("Step 7. PC1 探索性预警输出")

pc1          <- scores[, 1]
t_vec        <- time_points
baseline_end <- min(length(t_vec), max(2, floor(length(t_vec) * 0.5)))
mu           <- mean(pc1[1:baseline_end], na.rm = TRUE)
sdv          <- sd(pc1[1:baseline_end],   na.rm = TRUE)
if (is.na(sdv) || sdv < 1e-12) sdv <- 1e-12

thr2u <- mu + 2*sdv; thr3u <- mu + 3*sdv
thr2l <- mu - 2*sdv; thr3l <- mu - 3*sdv
warn  <- !is.na(pc1) & (abs(pc1 - mu) > 2*sdv)
alarm <- !is.na(pc1) & (abs(pc1 - mu) > 3*sdv)

write_csv_utf8(
  tibble(baseline_end = baseline_end, mu = mu, sd = sdv,
         threshold_2sd_upper = thr2u, threshold_2sd_lower = thr2l,
         threshold_3sd_upper = thr3u, threshold_3sd_lower = thr3l),
  file.path(out_dir, "20_pc1_monitoring_stats.csv")
)

png(file.path(out_dir, "pc1_warning.png"),
    width = 1100, height = 650, res = 150)
plot(t_vec, pc1, type = "b", pch = 19,
     xlab = "Time ", ylab = "PC1 score",
     main = "PC1 score with baseline thresholds")
abline(h = mu,    lty = 2)
abline(h = thr2u, lty = 2); abline(h = thr2l, lty = 2)
abline(h = thr3u, lty = 3); abline(h = thr3l, lty = 3)
idx_warn  <- which(warn); idx_alarm <- which(alarm)
if (length(idx_warn)  > 0) points(t_vec[idx_warn],  pc1[idx_warn],  pch = 1)
if (length(idx_alarm) > 0) {
  points(t_vec[idx_alarm], pc1[idx_alarm], pch = 4)
  text(t_vec[idx_alarm], pc1[idx_alarm], labels = "ALARM",
       pos = 3, cex = 0.7)
}
dev.off()

lam     <- 0.2
ewma    <- numeric(length(pc1))
ewma[1] <- pc1[1]
if (length(pc1) >= 2)
  for (i in 2:length(pc1)) ewma[i] <- lam*pc1[i] + (1-lam)*ewma[i-1]

sigma_ewma  <- sdv * sqrt(lam / (2 - lam))
L <- 3; ucl <- mu + L*sigma_ewma; lcl <- mu - L*sigma_ewma
drift_alarm <- !is.na(ewma) & ((ewma > ucl) | (ewma < lcl))

png(file.path(out_dir, "ewma_warning.png"),
    width = 1100, height = 650, res = 150)
plot(t_vec, ewma, type = "b", pch = 19,
     xlab = "Time (time_id)", ylab = "EWMA(PC1)",
     main = "EWMA drift detection")
abline(h = mu,  lty = 2)
abline(h = ucl, lty = 3); abline(h = lcl, lty = 3)
if (any(drift_alarm)) {
  points(t_vec[drift_alarm], ewma[drift_alarm], pch = 4)
  text(t_vec[drift_alarm], ewma[drift_alarm], labels = "DRIFT",
       pos = 3, cex = 0.7)
}
dev.off()

cat("\n主体分析完成。\n")
# =========================================================
# Season labels
# =========================================================
season_map <- c(
  "1" = "Spring",
  "2" = "Summer",
  "3" = "Autumn",
  "4" = "Winter"
)

# 如果 time_id 不一定正好是 1:4，可先检查
print(time_levels)

season_levels <- unname(season_map[as.character(time_levels)])

# 给颜色重新命名，后面图例/填充都更方便
time_cols_season <- time_cols
names(time_cols_season) <- season_levels
# =========================================================
# SECTION 11. Coastline & fishing ground data
# (依赖：df, x_min/max, y_min/max)
# =========================================================

print_section("Section 11. 读取海岸线与渔场数据")

time_id_col    <- "time_id"
fish_buf_ratio <- 0.10
fish_buf_min_x <- 0.08
fish_buf_min_y <- 0.08

coast_file <- "Coastline_china_2025.txt"
fish_file  <- "fish_area.csv"

if (!file.exists(coast_file)) stop("未找到 Coastline_china_2025.txt。")
if (!file.exists(fish_file))  stop("未找到 fish_area.csv。")
if (!(time_id_col %in% colnames(df)))
  stop(paste0("df 中没有列：", time_id_col))

# 读取海岸线
coast_raw <- tryCatch(
  read.table(coast_file, header = FALSE, fill = TRUE,
             blank.lines.skip = FALSE, stringsAsFactors = FALSE),
  error = function(e) read.csv(coast_file, header = FALSE, stringsAsFactors = FALSE)
)
if (ncol(coast_raw) < 2) stop("海岸线文件至少需要两列。")

lon_raw <- suppressWarnings(as.numeric(coast_raw[[1]]))
lat_raw <- suppressWarnings(as.numeric(coast_raw[[2]]))

jump_deg   <- c(Inf, sqrt(diff(lon_raw)^2 + diff(lat_raw)^2))
is_break   <- is.na(lon_raw) | is.na(lat_raw) | is.na(jump_deg) | jump_deg > 0.5
segment_id <- cumsum(is_break)

coast_df <- data.frame(longitude = lon_raw, latitude = lat_raw,
                       segment_id = segment_id)
coast_df <- coast_df[!is.na(coast_df$longitude) & !is.na(coast_df$latitude),
                     , drop = FALSE]
if (nrow(coast_df) == 0) stop("海岸线数据为空。")
cat("海岸线有效点数：", nrow(coast_df), "\n")

# 裁剪研究区
buffer_x  <- max(0.15, 0.08 * (x_max - x_min))
buffer_y  <- max(0.12, 0.08 * (y_max - y_min))
plot_xmin <- x_min - buffer_x;  plot_xmax <- x_max + buffer_x
plot_ymin <- y_min - buffer_y;  plot_ymax <- y_max + buffer_y

coast_crop <- coast_df[
  coast_df$longitude >= plot_xmin & coast_df$longitude <= plot_xmax &
    coast_df$latitude  >= plot_ymin & coast_df$latitude  <= plot_ymax,
  , drop = FALSE
]
if (nrow(coast_crop) == 0) {
  warning("裁剪后海岸线为空。"); coast_crop <- coast_df
}

if (nrow(coast_crop) > 50000) {
  cat("海岸线点数过多，简化中...\n")
  coast_list_tmp <- split(coast_crop, coast_crop$segment_id)
  coast_crop <- do.call(rbind, lapply(coast_list_tmp, thin_segment))
  rownames(coast_crop) <- NULL
}
coast_list <- split(coast_crop, coast_crop$segment_id)

# 采样点 factor
sampling_df <- df[, c("longitude", "latitude", time_id_col), drop = FALSE]
sampling_df[[time_id_col]] <- as.character(sampling_df[[time_id_col]])
time_levels <- sort(unique(sampling_df[[time_id_col]]))
sampling_df[[time_id_col]] <- factor(sampling_df[[time_id_col]], levels = time_levels)
time_cols <- grDevices::hcl.colors(length(time_levels), palette = "Dark 3")
names(time_cols) <- time_levels

# 渔场轮廓
fish_raw <- read.csv(fish_file, header = FALSE, stringsAsFactors = FALSE)
if (ncol(fish_raw) < 2) stop("fish_area.csv 至少需要两列。")
fish_lon <- suppressWarnings(as.numeric(fish_raw[[1]]))
fish_lat <- suppressWarnings(as.numeric(fish_raw[[2]]))
fish_ok  <- !is.na(fish_lon) & !is.na(fish_lat)
fish_lon <- fish_lon[fish_ok]; fish_lat <- fish_lat[fish_ok]
if (length(fish_lon) == 0) stop("fish_area.csv 无有效坐标。")

# 小图范围
fish_buf_x <- max(fish_buf_min_x, fish_buf_ratio * (max(fish_lon)-min(fish_lon)))
fish_buf_y <- max(fish_buf_min_y, fish_buf_ratio * (max(fish_lat)-min(fish_lat)))
inset_xmin <- min(fish_lon) - fish_buf_x;  inset_xmax <- max(fish_lon) + fish_buf_x
inset_ymin <- min(fish_lat) - fish_buf_y;  inset_ymax <- max(fish_lat) + fish_buf_y

# 小图采样点
samp_inset <- sampling_df[
  sampling_df$longitude >= inset_xmin & sampling_df$longitude <= inset_xmax &
    sampling_df$latitude  >= inset_ymin & sampling_df$latitude  <= inset_ymax,
  , drop = FALSE
]

# 小图海岸线（矢量）
coast_inset_raw <- coast_df[
  coast_df$longitude >= inset_xmin & coast_df$longitude <= inset_xmax &
    coast_df$latitude  >= inset_ymin & coast_df$latitude  <= inset_ymax,
  , drop = FALSE
]
coast_inset_vec_list <- if (nrow(coast_inset_raw) > 0) {
  tmp <- split(coast_inset_raw, coast_inset_raw$segment_id)
  tmp[sapply(tmp, nrow) >= 4]
} else list()

# =========================================================
# SECTION 12. Land mask (raster) & PDF size globals
# =========================================================

print_section("Section 12. 构建陆地栅格遮罩")

land_fill_col   <- "#3d3d3d"
land_border_col <- "#1a1a1a"

mask_lon_g <- lon_seq
mask_lat_g <- lat_seq
mask_pts_g <- expand.grid(lon = mask_lon_g, lat = mask_lat_g)

coast_for_pip  <- coast_df[
  coast_df$longitude >= plot_xmin & coast_df$longitude <= plot_xmax &
    coast_df$latitude  >= plot_ymin & coast_df$latitude  <= plot_ymax,
  , drop = FALSE
]
coast_pip_list <- split(coast_for_pip, coast_for_pip$segment_id)
coast_pip_list <- coast_pip_list[sapply(coast_pip_list, nrow) >= 10]
cat("陆地判断段数：", length(coast_pip_list), "\n")

is_land_g <- rep(FALSE, nrow(mask_pts_g))
for (k in seq_along(coast_pip_list)) {
  seg    <- coast_pip_list[[k]]
  closed <- close_segment_land_side(seg$longitude, seg$latitude,
                                    plot_xmin, plot_xmax, plot_ymin, plot_ymax)
  pip <- sp::point.in.polygon(
    point.x = mask_pts_g$lon, point.y = mask_pts_g$lat,
    pol.x   = closed$lon,     pol.y   = closed$lat)
  is_land_g <- is_land_g | (pip > 0)
  if (k %% 10 == 0 || k == length(coast_pip_list))
    cat(sprintf("  进度：%d / %d\n", k, length(coast_pip_list)))
}

land_mat_g     <- matrix(is_land_g, nrow = length(mask_lon_g),
                         ncol = length(mask_lat_g))
land_overlay_g <- matrix(NA_real_, nrow = length(mask_lon_g),
                         ncol = length(mask_lat_g))
land_overlay_g[land_mat_g] <- 1
cat("陆地占比：", round(mean(land_mat_g) * 100, 1), "%\n")

coast_lines_list <- coast_pip_list

# 栅格版陆地遮罩（供 eigenfunction / 热图使用）
add_land_coast <- function(lwd_coast = 0.8) {
  image(mask_lon_g, mask_lat_g, land_overlay_g,
        col = land_fill_col, add = TRUE)
  for (seg in coast_lines_list) {
    if (nrow(seg) >= 2)
      lines(seg$longitude, seg$latitude,
            col = land_border_col, lwd = lwd_coast)
  }
}

# 矢量版陆地填充（供采样点分布图使用）
fill_land_vector <- function(pip_list, xmin, xmax, ymin, ymax,
                             col = "#e8e0d0", lwd_coast = 0.7,
                             coast_line_col = "#4a4a4a") {
  for (seg in pip_list) {
    closed <- close_segment_land_side(
      seg$longitude, seg$latitude, xmin, xmax, ymin, ymax)
    polygon(closed$lon, closed$lat, col = col, border = NA)
  }
  for (seg in pip_list) {
    if (nrow(seg) >= 2)
      lines(seg$longitude, seg$latitude,
            col = coast_line_col, lwd = lwd_coast)
  }
}

# PDF 尺寸全局变量
pdf_w        <- 8
mar_eigen    <- c(3.5, 4.2, 2.8, 5.5)
mar_heat     <- c(3.5, 4.2, 2.8, 2.0)
lines_p_inch <- 0.20
xr_plot      <- plot_xmax - plot_xmin
yr_plot      <- plot_ymax - plot_ymin
pdf_h_eigen  <- compute_pdf_h(pdf_w, mar_eigen, xr_plot, yr_plot)
pdf_h_heat   <- compute_pdf_h(pdf_w, mar_heat,  xr_plot, yr_plot)

# =========================================================
# SECTION 13. Sampling locations figure (2×2 with inset)
# =========================================================

print_section("Section 13. 采样点分布图")

ocean_col <- "#cce5f5"
land_col  <- "#e8e0d0"
coast_col <- "#4a4a4a"
link_col  <- "#c0392b"

mar_loc   <- c(3.0, 3.6, 2.4, 0.8)
pdf_h_loc <- compute_pdf_h(pdf_w, mar_loc, xr_plot, yr_plot)

total_w   <- pdf_w * 2
total_h   <- pdf_h_loc * 2
oma_frac  <- min(0.12, 2.0 * lines_p_inch / total_h)

ax0 <- 0; ax1 <- 1
ay0 <- 0; ay1 <- 1 - oma_frac
pw  <- (ax1 - ax0) / 2
ph  <- (ay1 - ay0) / 2

panel_figs <- list(
  c(ax0,      ax0 + pw, ay0 + ph, ay1     ),
  c(ax0 + pw, ax1,      ay0 + ph, ay1     ),
  c(ax0,      ax0 + pw, ay0,      ay0 + ph),
  c(ax0 + pw, ax1,      ay0,      ay0 + ph)
)

ins_mar         <- c(1.4, 1.4, 1.0, 0.35)
xr_ins          <- inset_xmax - inset_xmin
yr_ins          <- inset_ymax - inset_ymin
ins_plot_w_frac <- 0.22

fname_loc <- file.path(out_dir, "sampling_locations_by_survey.pdf")
pdf(fname_loc, width = total_w, height = total_h)

for (i_tid in seq_along(time_levels)) {
  
  tid  <- time_levels[i_tid]
  pfig <- panel_figs[[i_tid]]
  
  par(fig = pfig, new = (i_tid > 1), mar = mar_loc)
  
  plot(NA,
       xlim = c(plot_xmin, plot_xmax),
       ylim = c(plot_ymin, plot_ymax),
       xlab = "Longitude (\u00b0E)", ylab = "Latitude (\u00b0N)",
       asp  = 1, axes = TRUE, frame.plot = FALSE, type = "n",
       cex.axis = 0.80, cex.lab = 0.88,
       tcl = -0.25, mgp = c(2.2, 0.5, 0))
  
  rect(plot_xmin, plot_ymin, plot_xmax, plot_ymax,
       col = ocean_col, border = NA)
  
  fill_land_vector(coast_pip_list,
                   plot_xmin, plot_xmax, plot_ymin, plot_ymax,
                   lwd_coast = 0.7)
  
  idx_t <- sampling_df[[time_id_col]] == tid
  n_pts <- sum(idx_t)
  if (n_pts > 0)
    points(sampling_df$longitude[idx_t], sampling_df$latitude[idx_t],
           pch = 21, cex = 0.6,
           bg  = time_cols[as.character(tid)], col = "white", lwd = 0.55)
  
  rect(inset_xmin, inset_ymin, inset_xmax, inset_ymax,
       border = link_col, lwd = 1.1, lty = 2)
  
  box_ndc_xl <- grconvertX(inset_xmin, "user", "ndc")
  box_ndc_xr <- grconvertX(inset_xmax, "user", "ndc")
  box_ndc_yb <- grconvertY(inset_ymin, "user", "ndc")
  
  ndc_right     <- grconvertX(plot_xmax, "user", "ndc")
  ndc_bottom    <- grconvertY(plot_ymin, "user", "ndc")
  ndc_left_edge <- grconvertX(plot_xmin, "user", "ndc")
  ndc_plot_w    <- ndc_right - ndc_left_edge
  
  title(paste0("Survey round ", tid, "  (n\u00a0=\u00a0", n_pts, ")"),
        cex.main = 0.95, font.main = 1, line = 0.8)
  box(lwd = 0.7, col = "#444444")
  
  ins_w_ndc        <- ndc_plot_w * ins_plot_w_frac
  ins_w_inch       <- ins_w_ndc * total_w
  ins_data_h_inch  <- ins_w_inch * (yr_ins / xr_ins) *
    cos(mean(c(inset_ymin, inset_ymax)) * pi / 180)
  ins_total_h_inch <- ins_data_h_inch + (ins_mar[1] + ins_mar[3]) * lines_p_inch
  ins_h_ndc        <- ins_total_h_inch / total_h
  
  fig_ins <- c(
    ndc_right - ins_w_ndc,
    ndc_right,
    ndc_bottom,
    ndc_bottom + ins_h_ndc
  )
  
  par(fig = fig_ins, new = TRUE, mar = ins_mar)
  
  x_ticks <- round(seq(inset_xmin, inset_xmax, length.out = 3), 2)
  y_ticks <- round(seq(inset_ymin, inset_ymax, length.out = 3), 2)
  
  plot(NA,
       xlim = c(inset_xmin, inset_xmax),
       ylim = c(inset_ymin, inset_ymax),
       xlab = "", ylab = "",
       asp  = 1, axes = FALSE, frame.plot = TRUE, type = "n")
  
  axis(1, at = x_ticks,
       labels = formatC(x_ticks, format = "f", digits = 2),
       cex.axis = 0.45, tcl = -0.16, mgp = c(0.65, 0.22, 0), lwd = 0.55)
  axis(2, at = y_ticks,
       labels = formatC(y_ticks, format = "f", digits = 2),
       cex.axis = 0.45, tcl = -0.16, mgp = c(0.65, 0.22, 0), lwd = 0.55, las = 1)
  
  rect(inset_xmin, inset_ymin, inset_xmax, inset_ymax,
       col = ocean_col, border = NA)
  
  if (length(coast_inset_vec_list) > 0)
    fill_land_vector(coast_inset_vec_list,
                     inset_xmin, inset_xmax, inset_ymin, inset_ymax,
                     lwd_coast = 0.45)
  
  idx_ins <- samp_inset[[time_id_col]] == tid
  if (any(idx_ins))
    points(samp_inset$longitude[idx_ins], samp_inset$latitude[idx_ins],
           pch = 21, cex = 0.50,
           bg  = time_cols[as.character(tid)], col = "white", lwd = 0.30)
  
  polygon(x = c(fish_lon, fish_lon[1]),
          y = c(fish_lat, fish_lat[1]),
          border = link_col, lwd = 1.25, col = NA)
  
  title("Fishing ground", cex.main = 0.65, line = 0.25, font.main = 1)
  box(lwd = 0.85, col = "#444444")
  
  ins_ndc_xl <- grconvertX(par("usr")[1], "user", "ndc")
  ins_ndc_xr <- grconvertX(par("usr")[2], "user", "ndc")
  ins_ndc_yt <- grconvertY(par("usr")[4], "user", "ndc")
  
  par(fig = c(0, 1, 0, 1), new = TRUE,
      mar = c(0, 0, 0, 0), xpd = TRUE)
  plot(NA, xlim = c(0, 1), ylim = c(0, 1),
       axes = FALSE, xlab = "", ylab = "", type = "n",
       xaxs = "i", yaxs = "i")
  
  segments(
    x0 = c(box_ndc_xl, box_ndc_xr),
    y0 = c(box_ndc_yb, box_ndc_yb),
    x1 = c(ins_ndc_xl, ins_ndc_xr),
    y1 = c(ins_ndc_yt, ins_ndc_yt),
    col = link_col, lwd = 0.9, lty = 2
  )
}

par(fig = c(0, 1, 0, 1), new = TRUE, mar = c(0, 0, 0, 0))
plot.new()
mtext("Spatial distribution of water-quality sampling locations",
      side = 3, line = -1.4, cex = 1.05, font = 2)

dev.off()
cat("采样点分布图已保存：", basename(fname_loc), "\n")

# =========================================================
# SECTION 14. PC variable contribution bar chart
# =========================================================

print_section("Section 14. PC 变量贡献条形图")

var_label_map <- c(
  "T（℃）"                 = "Temperature (\u00b0C)",
  "DOf"                     = "DO saturation (%)",
  "非离子氨（mg/L）"        = "Un-ionized NH\u2083 (mg/L)",
  "S（%。）"                = "Salinity (\u2030)",
  "化学需氧量COD（mg/L）"   = "COD (mg/L)",
  "钒（mg/L）"              = "V (mg/L)",
  "铬（mg/L）"              = "Cr (mg/L)",
  "无机磷DIP（mg/L）"       = "DIP (mg/L)",
  "铅（mg/L）"              = "Pb (mg/L)",
  "镉（mg/L）"              = "Cd (mg/L)",
  "TOC（有机碳）"           = "TOC (mg/L)",
  "pH"                      = "pH",
  "总磷TP（mg/L）"          = "TP (mg/L)",
  "叶绿素a"                 = "Chl-a (\u03bcg/L)",
  "水深（m)"                = "Water depth (m)",
  "无机氮DIN（mg/L）"       = "DIN (mg/L)"
)

contrib_plot_df <- pc_var_contrib_top %>%
  mutate(
    var_label = dplyr::coalesce(var_label_map[original_variable_name],
                                original_variable_name),
    PC = factor(PC, levels = c("PC1", "PC2", "PC3"))
  ) %>%
  arrange(PC, relative_energy) %>%
  mutate(var_label = factor(var_label, levels = unique(var_label)))

p_contrib <- ggplot(contrib_plot_df,
                    aes(x = relative_energy * 100, y = var_label)) +
  geom_col(fill = "#4575b4", width = 0.65) +
  geom_text(aes(label = sprintf("%.1f%%", relative_energy * 100)),
            hjust = -0.15, size = 2.8, color = "grey30") +
  facet_wrap(~ PC, ncol = 3, scales = "free_y") +
  scale_x_continuous(expand = expansion(mult = c(0, 0.22))) +
  labs(x = "Relative contribution (%)", y = NULL) +
  theme_bw(base_size = 10) +
  theme(
    panel.grid.major.y = element_blank(),
    panel.grid.minor   = element_blank(),
    strip.background   = element_rect(fill = "#e8e0d0", color = NA),
    strip.text         = element_text(face = "bold", size = 10),
    axis.text.y        = element_text(size = 8.5),
    axis.text.x        = element_text(size = 8),
    plot.margin        = margin(6, 14, 6, 6)
  )

ggsave(file.path(out_dir, "pc_variable_contribution.pdf"),
       p_contrib, width = 7, height = 4, dpi = 300)
cat("变量贡献图已保存：pc_variable_contribution.pdf\n")

# =========================================================
# SECTION 15. PC1 vs PC2 biplot
# =========================================================
# =========================================================
# SECTION 15. PC1 vs PC2 biplot
# =========================================================
# =========================================================
# SECTION 15. PC1 vs PC2 biplot
# =========================================================

print_section("Section 15. PC1 vs PC2 得分散点图")

library(ggplot2)
library(ggrepel)

scores_mat <- as.matrix(scores)

stopifnot(ncol(scores_mat) >= 2)
stopifnot(length(prop_each) >= 2)
stopifnot(exists("time_cols"))
stopifnot(exists("out_dir"))

if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

scores_plot_df <- data.frame(
  survey_round = factor(
    season_map[as.character(time_points)],
    levels = c("Spring", "Summer", "Autumn", "Winter")
  ),
  PC1 = scores_mat[, 1],
  PC2 = scores_mat[, 2]
)

pc1_pct <- round(prop_each[1] * 100, 1)
pc2_pct <- round(prop_each[2] * 100, 1)

print(time_cols)
print(levels(scores_plot_df$survey_round))

p_scores <- ggplot(scores_plot_df, aes(x = PC1, y = PC2)) +
  geom_hline(yintercept = 0, linetype = "dashed",
             color = "grey60", linewidth = 0.4) +
  geom_vline(xintercept = 0, linetype = "dashed",
             color = "grey60", linewidth = 0.4) +
  geom_point(aes(fill = survey_round), shape = 21,
             size = 4.5, color = "white", stroke = 0.6) +
  ggrepel::geom_label_repel(
    aes(label = survey_round),
    size = 3.2,
    box.padding = 0.45,
    point.padding = 0.3,
    segment.color = "grey50",
    segment.size = 0.35,
    fill = "white",
    label.size = 0.2,
    color = "grey20"
  ) +
  scale_fill_manual(values = time_cols_season, guide = "none") +
  labs(
    x = paste0("PC1 (", pc1_pct, "% variance explained)"),
    y = paste0("PC2 (", pc2_pct, "% variance explained)")
  ) +
  theme_bw(base_size = 11) +
  theme(
    panel.grid.major = element_blank(),
    panel.grid.minor = element_blank(),
    axis.title = element_text(size = 10),
    axis.text = element_text(size = 9),
    plot.margin = margin(8, 12, 6, 8)
  )

print(p_scores)

ggsave(
  filename = file.path(out_dir, "scores_biplot.pdf"),
  plot = p_scores,
  width = 5,
  height = 4.2,
  dpi = 300
)

cat("得分散点图已保存：scores_biplot.pdf\n")
# =========================================================
# SECTION 16. Eigenfunction figures (top-PC representatives + PC1 top-5)
# =========================================================

print_section("Section 16. Eigenfunction 代表图")

n_col_ef  <- 200
pal_eigen <- colorRampPalette(c(
  "#313695","#4575b4","#74add1","#abd9e9","#e0f3f8",
  "#ffffbf",
  "#fee090","#fdae61","#f46d43","#d73027","#a50026"
))(n_col_ef)

samp_col      <- "#2c7fb8"
samp_cex_fig1 <- 0.35
samp_cex_fig2 <- 0.30

draw_colorbar <- function(zlim, pal, title = "Loading") {
  u <- par("usr")
  old_fig <- par("fig"); old_mar <- par("mar"); old_xpd <- par("xpd")
  
  plot_right_ndc  <- grconvertX(u[2], "user", "ndc")
  plot_bottom_ndc <- grconvertY(u[3], "user", "ndc")
  plot_top_ndc    <- grconvertY(u[4], "user", "ndc")
  
  total_w_inch <- par("din")[1]
  cb_w_inch   <- 0.10
  cb_gap_inch <- 0.14
  cb_x0_ndc   <- plot_right_ndc + cb_gap_inch / total_w_inch
  cb_x1_ndc   <- cb_x0_ndc      + cb_w_inch   / total_w_inch
  
  par(fig = c(0,1,0,1), new = TRUE, mar = c(0,0,0,0), xpd = NA)
  plot(NA, xlim = c(0,1), ylim = c(0,1),
       axes = FALSE, xlab = "", ylab = "",
       xaxs = "i", yaxs = "i", type = "n")
  
  yy <- seq(plot_bottom_ndc, plot_top_ndc, length.out = n_col_ef + 1)
  for (k in seq_len(n_col_ef))
    rect(cb_x0_ndc, yy[k], cb_x1_ndc, yy[k+1], col = pal[k], border = NA)
  rect(cb_x0_ndc, plot_bottom_ndc, cb_x1_ndc, plot_top_ndc,
       border = "black", lwd = 0.6)
  
  n_tick <- 5
  tick_y <- seq(plot_bottom_ndc, plot_top_ndc, length.out = n_tick)
  tick_v <- seq(zlim[1], zlim[2], length.out = n_tick)
  for (k in seq_len(n_tick)) {
    segments(cb_x1_ndc, tick_y[k],
             cb_x1_ndc + 0.0065, tick_y[k], lwd = 0.6)
    text(cb_x1_ndc + 0.0065 * 1.5, tick_y[k],
         formatC(tick_v[k], digits = 2, format = "f"),
         cex = 0.48, adj = c(0, 0.5))
  }
  text((cb_x0_ndc + cb_x1_ndc) / 2,
       plot_top_ndc + 0.020,
       labels = title, cex = 0.52, adj = c(0.5, 0))
  
  par(fig = old_fig, mar = old_mar, xpd = old_xpd)
}

add_panel_label <- function(letter, cex_lab = 0.82) {
  usr <- par("usr")
  x <- usr[1] + 0.025 * (usr[2] - usr[1])
  y <- usr[4] - 0.035 * (usr[4] - usr[3])
  text(x, y, labels = paste0("(", letter, ")"),
       adj = c(0, 1), font = 2, cex = cex_lab)
}

# ---- 第一张：PC1/PC2/PC3 代表变量（3×1 竖排）----
pc_rep_vars <- c(
  pc_var_contrib_top %>% filter(PC=="PC1") %>% arrange(rank_within_pc) %>%
    slice(1) %>% pull(variable),
  pc_var_contrib_top %>% filter(PC=="PC2") %>% arrange(rank_within_pc) %>%
    slice(1) %>% pull(variable),
  pc_var_contrib_top %>% filter(PC=="PC3") %>% arrange(rank_within_pc) %>%
    slice(1) %>% pull(variable)
)
pc_rep_labels <- c(
  "PC1 \u2014 Temperature (\u00b0C)",
  "PC2 \u2014 Vanadium (mg/L)",
  "PC3 \u2014 Total organic carbon (mg/L)"
)

mar_fig1  <- c(3.2, 4.6, 1.9, 4.4)
panel_w_3 <- 5.4
panel_h_3 <- compute_pdf_h(panel_w_3, mar_fig1, xr_plot, yr_plot)

panel_figs_3 <- list(
  c(0, 1, 2/3, 1),
  c(0, 1, 1/3, 2/3),
  c(0, 1, 0,   1/3)
)

pdf(file.path(out_dir, "eigenfunction_PC123_representative.pdf"),
    width = panel_w_3, height = panel_h_3 * 3)

for (k in 1:3) {
  pfig3 <- panel_figs_3[[k]]
  par(fig = pfig3, new = (k > 1), mar = mar_fig1,
      mgp = c(2.4, 0.6, 0))
  
  var_idx  <- which(variables == pc_rep_vars[k])
  phi_mat  <- extract_surface(mfpca_result$functions[[var_idx]][k])
  abs_max  <- max(abs(phi_mat), na.rm = TRUE)
  if (abs_max < 1e-12) abs_max <- 1
  zlim_sym <- c(-abs_max, abs_max)
  
  image(lon_seq, lat_seq, phi_mat,
        zlim  = zlim_sym, col = pal_eigen,
        xlab  = "Longitude (\u00b0E)",
        ylab  = "Latitude (\u00b0N)",
        asp   = 1, axes = TRUE,
        main  = pc_rep_labels[k],
        cex.main = 0.92, cex.axis = 0.78, cex.lab = 0.88)
  
  add_land_coast(lwd_coast = 0.7)
  
  points(sampling_df$longitude, sampling_df$latitude,
         pch = 19, cex = samp_cex_fig1, col = samp_col)
  
  add_panel_label(letters[k], cex_lab = 0.86)
  box()
  draw_colorbar(zlim_sym, pal_eigen, title = "Loading")
}
dev.off()
cat("三 PC 代表图已保存：eigenfunction_PC123_representative.pdf\n")

# ---- 第二张：PC1 前 5 变量（2 + 3 布局）----
pc1_top5_vars <- pc_var_contrib_top %>%
  filter(PC == "PC1") %>% arrange(rank_within_pc) %>% pull(variable)

pc1_top5_labels <- c(
  "Temperature (\u00b0C)",
  "DO saturation (%)",
  "Un-ionized NH\u2083 (mg/L)",
  "Salinity (\u2030)",
  "COD (mg/L)"
)

mar_fig2  <- c(2.5, 2.9, 1.8, 4.3)
panel_w_5 <- 2.6
panel_h_5 <- compute_pdf_h(panel_w_5, mar_fig2, xr_plot, yr_plot)
total_w_5 <- panel_w_5 * 3
total_h_5 <- panel_h_5 * 2

col_x <- c(0, 1/3, 2/3, 1)
row_y <- c(0, 0.5, 1)
cx    <- 1/6

panel_figs_5 <- list(
  c(cx,       cx + 1/3, row_y[2], row_y[3]),
  c(cx + 1/3, cx + 2/3, row_y[2], row_y[3]),
  c(col_x[1], col_x[2], row_y[1], row_y[2]),
  c(col_x[2], col_x[3], row_y[1], row_y[2]),
  c(col_x[3], col_x[4], row_y[1], row_y[2])
)

pdf(file.path(out_dir, "eigenfunction_PC1_top5.pdf"),
    width = total_w_5, height = total_h_5)

for (k in seq_along(pc1_top5_vars)) {
  pfig5   <- panel_figs_5[[k]]
  var_idx <- which(variables == pc1_top5_vars[k])
  
  phi_mat  <- extract_surface(mfpca_result$functions[[var_idx]][1])
  abs_max  <- max(abs(phi_mat), na.rm = TRUE)
  if (abs_max < 1e-12) abs_max <- 1
  zlim_sym <- c(-abs_max, abs_max)
  
  par(fig = pfig5, new = (k > 1), mar = mar_fig2)
  
  image(lon_seq, lat_seq, phi_mat,
        zlim  = zlim_sym, col = pal_eigen,
        xlab  = "Longitude (\u00b0E)",
        ylab  = "Latitude (\u00b0N)",
        asp   = 1, axes = TRUE,
        main  = pc1_top5_labels[k],
        cex.main = 0.84, cex.axis = 0.70, cex.lab = 0.80)
  
  add_land_coast(lwd_coast = 0.7)
  
  points(sampling_df$longitude, sampling_df$latitude,
         pch = 19, cex = samp_cex_fig2, col = samp_col)
  
  add_panel_label(letters[k], cex_lab = 0.80)
  box()
  draw_colorbar(zlim_sym, pal_eigen, title = "Loading")
}
dev.off()
cat("PC1 前5变量图已保存：eigenfunction_PC1_top5.pdf\n")

# =========================================================
# SECTION 17. Sensitivity heatmap
# =========================================================

print_section("Section 17. 灵敏度热图")

j_h    <- 1
pc_h   <- 1
t_pick <- which.max(abs(scores[, pc_h]))
phi_h  <- extract_surface(mfpca_result$functions[[j_h]][pc_h])
heat   <- abs(phi_h) * abs(scores[t_pick, pc_h])

q_val  <- 0.98
th     <- quantile(heat, q_val, na.rm = TRUE)
mask_h <- heat >= th
idx_h  <- which(mask_h, arr.ind = TRUE)

write_csv_utf8(
  tibble(selected_variable  = orig_var_names_final[j_h],
         selected_time_id   = time_points[t_pick],
         quantile_threshold = q_val,
         threshold_value    = th,
         hotspot_ratio      = mean(mask_h)),
  file.path(out_dir, "23_hotspot_summary.csv")
)

pdf(file.path(out_dir, "sensitivity_heatmap.pdf"),
    width = pdf_w, height = pdf_h_heat)
par(mar = mar_heat)
image(lon_seq, lat_seq, heat,
      col  = viridis::viridis(256),
      xlab = "Longitude (\u00b0E)", ylab = "Latitude (\u00b0N)",
      asp  = 1, axes = TRUE,
      main = paste0("Sensitivity heatmap: ",
                    safe_label(orig_var_names_final[j_h]),
                    "  (time_id = ", time_points[t_pick], ")"))
add_land_coast(lwd_coast = 0.9)
if (nrow(idx_h) > 0) {
  xs <- lon_seq[idx_h[,1]]; ys <- lat_seq[idx_h[,2]]
  rect(min(xs), min(ys), max(xs), max(ys),
       border = "white", lwd = 2, lty = 2)
}
box()
dev.off()
cat("灵敏度热图已保存：sensitivity_heatmap.pdf\n")

# =========================================================
# SECTION 18. Batch eigenfunction PDFs (all PC × variables)
# =========================================================

print_section("Section 18. 批量输出所有 Eigenfunction PDF")

draw_eigenfunction_pdf <- function(pc_idx, var_idx) {
  phi_mat   <- extract_surface(mfpca_result$functions[[var_idx]][pc_idx])
  var_label <- safe_label(orig_var_names_final[var_idx])
  abs_max   <- max(abs(phi_mat), na.rm = TRUE)
  if (is.na(abs_max) || abs_max < 1e-12) abs_max <- 1
  zlim_sym  <- c(-abs_max, abs_max)
  
  image(lon_seq, lat_seq, phi_mat,
        zlim = zlim_sym, col = pal_eigen,
        xlab = "Longitude (\u00b0E)", ylab = "Latitude (\u00b0N)",
        asp = 1, axes = TRUE,
        main = paste0("PC", pc_idx, " Eigenfunction  \u2014  ", var_label))
  
  add_land_coast(lwd_coast = 0.8)
  
  for (lev in time_levels) {  
    idx_s <- sampling_df[[time_id_col]] == lev
    if (any(idx_s))
      points(sampling_df$longitude[idx_s], sampling_df$latitude[idx_s],
             pch = 19, cex = 0.7, col = time_cols[lev])
  }
  legend("topleft", legend = time_levels, col = time_cols,
         pch = 19, pt.cex = 0.85, bty = "n",
         title = "Survey round", cex = 0.75)
  box()
  
  u  <- par("usr")
  pw_u <- u[2] - u[1]; ph_u <- u[4] - u[3]
  x0 <- u[2] + pw_u * 0.025
  x1 <- x0   + pw_u * 0.030
  ys <- seq(u[3], u[4], length.out = n_col_ef + 1)
  
  par(xpd = TRUE)
  for (k in seq_len(n_col_ef))
    rect(x0, ys[k], x1, ys[k+1], col = pal_eigen[k], border = NA)
  rect(x0, u[3], x1, u[4], border = "black", lwd = 0.7)
  
  ty <- seq(u[3], u[4], length.out = 5)
  tv <- seq(zlim_sym[1], zlim_sym[2], length.out = 5)
  for (k in 1:5) {
    segments(x1, ty[k], x1 + pw_u*0.010, ty[k], lwd = 0.7)
    text(x1 + pw_u*0.018, ty[k],
         formatC(tv[k], digits = 3, format = "f"),
         cex = 0.60, adj = c(0, 0.5))
  }
  text((x0+x1)/2, u[4] + ph_u*0.04, "Loading",
       cex = 0.70, adj = c(0.5, 0))
  par(xpd = FALSE)
}

n_saved <- 0
for (pc_idx in seq_len(M_use)) {
  for (var_idx in seq_along(variables)) {
    safe_vn <- gsub("[^A-Za-z0-9_]", "_", orig_var_names_final[var_idx])
    fname   <- file.path(out_dir,
                         sprintf("eigenfunction_PC%d_%s.pdf", pc_idx, safe_vn))
    pdf(fname, width = pdf_w, height = pdf_h_eigen)
    par(mar = mar_eigen)
    tryCatch(
      draw_eigenfunction_pdf(pc_idx, var_idx),
      error = function(e)
        message("跳过 PC", pc_idx, " Var", var_idx, ": ", conditionMessage(e))
    )
    dev.off()
    n_saved <- n_saved + 1
    cat("已保存：", basename(fname), "\n")
  }
}

cat("\n全部完成，共输出", n_saved, "张 Eigenfunction PDF。\n")
cat("所有结果已输出到:", out_dir, "\n")
#==============================================================
# 查看 PC1 所有变量的完整贡献排序
pc1_all_contrib <- list()

for (j in seq_along(variables)) {
  phi      <- extract_surface(mfpca_result$functions[[j]][1])
  energy_j <- mean(phi^2, na.rm = TRUE)
  pc1_all_contrib[[j]] <- tibble(
    rank          = NA,
    clean_name    = variables[j],
    original_name = orig_var_names_final[j],
    energy        = energy_j
  )
}

pc1_full_df <- bind_rows(pc1_all_contrib) %>%
  mutate(
    relative_energy = energy / sum(energy) * 100,
    rank = rank(-energy, ties.method = "first")
  ) %>%
  arrange(rank)

# 打印完整排序
print(pc1_full_df, n = nrow(pc1_full_df))

# 单独查看 DO 的排名
pc1_full_df %>% filter(grepl("DO|溶解氧", original_name, ignore.case = TRUE))

# 保存完整排序表
write_csv_utf8(pc1_full_df,
               file.path(out_dir, "pc1_full_variable_ranking.csv"))


# 看 DO 的空间变异有多大
df %>%
  group_by(time_id) %>%
  summarise(
    do_mean = mean(.data[[clean_var_names[which(orig_var_names == "DO(mg/L)")]]], na.rm = TRUE),
    do_sd   = sd(.data[[clean_var_names[which(orig_var_names == "DO(mg/L)")]]], na.rm = TRUE),
    do_cv   = do_sd / do_mean * 100
  )
# 查看 DO 在三个 PC 的贡献排名
pc1_full_df %>%
  filter(grepl("DO|溶解氧", original_name, ignore.case = TRUE))

# 同时看 PC2 和 PC3 的完整排序里 DO 在哪里
for (pc_idx in 1:3) {
  cat("\n=== PC", pc_idx, "===\n")
  tmp <- list()
  for (j in seq_along(variables)) {
    phi <- extract_surface(mfpca_result$functions[[j]][pc_idx])
    tmp[[j]] <- tibble(
      original_name   = orig_var_names_final[j],
      energy          = mean(phi^2, na.rm = TRUE)
    )
  }
  bind_rows(tmp) %>%
    mutate(relative_energy = energy / sum(energy) * 100,
           rank = rank(-energy, ties.method = "first")) %>%
    arrange(rank) %>%
    filter(grepl("DO|溶解氧", original_name, ignore.case = TRUE)) %>%
    print()
}
# 查看 DO 各轮次的有效观测数和缺失率
missingness_by_time_variable %>%
  filter(grepl("DO|溶解氧", original_name, ignore.case = TRUE))
#==============================================================================
# =========================================================
# SECTION 11. MFPCA 适用性诊断
#   1) KMO      (Kaiser–Meyer–Olkin Measure of Sampling Adequacy)
#   2) Bartlett Sphericity Test
#   3) Moran's I (每个变量×每个轮次)
# 依赖：df, clean_var_names, var_lookup_final, time_points
# =========================================================

print_section("Section 11. MFPCA 适用性诊断：KMO + Bartlett + Moran's I")

# ---- 安装/加载包 ----
if (!requireNamespace("psych", quietly = TRUE))
  install.packages("psych")
if (!requireNamespace("ape", quietly = TRUE))
  install.packages("ape")
suppressPackageStartupMessages({
  library(psych)
  library(ape)
})

# ---- 准备诊断数据：所有时间点合并，去缺失 ----
pca_diag_data <- df %>%
  select(all_of(clean_var_names)) %>%
  na.omit()

cat("诊断用样本数：", nrow(pca_diag_data), "\n")
cat("诊断变量数  ：", ncol(pca_diag_data), "\n")

# =========================================================
# =========================================================
# 诊断修复：剔除共线变量后重新 KMO + Bartlett
# =========================================================

# ---- Step 1: 检查共线性 ----
cor_mat <- cor(pca_diag_data, use = "pairwise.complete.obs")
det_val <- det(cor_mat)
cat("相关矩阵行列式 =", format(det_val, scientific = TRUE, digits = 4), "\n")
cat("(接近 0 表示存在共线性)\n\n")

# ---- Step 2: 识别并剔除衍生/冗余变量 ----
# 根据变量含义，这些是其他变量的函数：
redundant_patterns <- c("DIN", "营养指数E", "营养状态质量指数",
                        "NQI", "有机污染评价指数", "叶绿素b", "叶绿素c")

redundant_clean <- var_lookup_final$clean_name[
  sapply(var_lookup_final$original_name, function(x)
    any(sapply(redundant_patterns, function(p) grepl(p, x, fixed = TRUE))))
]

cat("识别出的冗余/衍生变量：\n")
print(var_lookup_final %>% filter(clean_name %in% redundant_clean))

# ---- Step 3: 用 caret 自动剔除高相关变量（r > 0.95）----
if (!requireNamespace("caret", quietly = TRUE)) install.packages("caret")
library(caret)

reduced_data <- pca_diag_data %>% select(-all_of(redundant_clean))
cor_reduced  <- cor(reduced_data, use = "pairwise.complete.obs")
high_cor_idx <- caret::findCorrelation(cor_reduced, cutoff = 0.95,
                                       names = FALSE)
if (length(high_cor_idx) > 0) {
  auto_drop <- colnames(reduced_data)[high_cor_idx]
  cat("\n自动剔除 r > 0.95 的冗余变量：\n")
  print(var_lookup_final %>% filter(clean_name %in% auto_drop))
  reduced_data <- reduced_data[, -high_cor_idx, drop = FALSE]
}

cat("\n最终用于诊断的变量数：", ncol(reduced_data), "\n")
cat("样本数：", nrow(reduced_data), "\n")

# ---- Step 4: 重新 KMO ----
kmo_reduced <- psych::KMO(reduced_data)
cat("\n---------- 修正后 KMO ----------\n")
cat("Overall KMO =", round(kmo_reduced$MSA, 4), "\n")

kmo_ind_reduced <- tibble(
  clean_name    = names(kmo_reduced$MSAi),
  original_name = var_lookup_final$original_name[
    match(names(kmo_reduced$MSAi),
          var_lookup_final$clean_name)],
  MSA           = as.numeric(kmo_reduced$MSAi)
) %>% arrange(MSA)
print(kmo_ind_reduced, n = nrow(kmo_ind_reduced))

# ---- Step 5: 重新 Bartlett ----
cor_final <- cor(reduced_data, use = "pairwise.complete.obs")
bart_reduced <- psych::cortest.bartlett(R = cor_final,
                                        n = nrow(reduced_data))
cat("\n---------- 修正后 Bartlett ----------\n")
cat("Chi-square =", round(bart_reduced$chisq, 2), "\n")
cat("df         =", bart_reduced$df, "\n")
cat("p-value    =", format.pval(bart_reduced$p.value), "\n")

# ---- Step 6: 保存 ----
write_csv_utf8(
  tibble(statistic = c("Overall_KMO", "Bartlett_chi2",
                       "Bartlett_df", "Bartlett_p",
                       "N_samples", "N_variables"),
         value = c(kmo_reduced$MSA,
                   bart_reduced$chisq,
                   bart_reduced$df,
                   bart_reduced$p.value,
                   nrow(reduced_data),
                   ncol(reduced_data))),
  file.path(out_dir, "30c_kmo_bartlett_corrected.csv")
)
write_csv_utf8(kmo_ind_reduced,
               file.path(out_dir, "30d_kmo_by_variable_corrected.csv"))

cat("\n修正后结果已保存到：30c_kmo_bartlett_corrected.csv\n")
# =========================================================
# 3. Moran's I —— 每个变量在每个轮次上的空间自相关
# =========================================================
cat("\n---------- 3. Moran's I 空间自相关 ----------\n")

moran_results <- list()

for (t in time_points) {
  d_t <- df %>% filter(time_id == t) %>%
    select(longitude, latitude, all_of(clean_var_names))
  
  # 距离矩阵 → 反距离权重
  coords <- cbind(d_t$longitude, d_t$latitude)
  d_mat  <- as.matrix(dist(coords))
  w      <- 1 / d_mat
  diag(w) <- 0
  # 行标准化（每行权重和为 1），减轻样本数差异影响
  row_sums <- rowSums(w)
  row_sums[row_sums == 0] <- 1
  w <- w / row_sums
  
  for (v in clean_var_names) {
    x <- d_t[[v]]
    keep <- !is.na(x)
    if (sum(keep) < 10 || sd(x[keep]) < 1e-12) next
    
    mi <- tryCatch(
      ape::Moran.I(x[keep], w[keep, keep], scaled = TRUE),
      error = function(e) NULL
    )
    if (!is.null(mi)) {
      moran_results[[paste(t, v, sep = "_")]] <- tibble(
        time_id       = t,
        variable      = v,
        original_name = var_lookup_final$original_name[
          match(v, var_lookup_final$clean_name)],
        moran_I       = mi$observed,
        expected      = mi$expected,
        sd_I          = mi$sd,
        p_value       = mi$p.value
      )
    }
  }
  cat("  Moran's I 计算完成：time_id =", t, "\n")
}

moran_df <- bind_rows(moran_results)

# 每个变量的汇总
moran_summary <- moran_df %>%
  group_by(variable, original_name) %>%
  summarise(
    mean_I        = mean(moran_I, na.rm = TRUE),
    min_I         = min(moran_I, na.rm = TRUE),
    max_I         = max(moran_I, na.rm = TRUE),
    mean_p        = mean(p_value, na.rm = TRUE),
    n_rounds      = n(),
    n_sig_rounds  = sum(p_value < 0.05, na.rm = TRUE),
    prop_sig      = n_sig_rounds / n_rounds,
    .groups = "drop"
  ) %>% arrange(desc(mean_I))

cat("\nMoran's I 按变量汇总（按平均 I 降序）：\n")
print(moran_summary, n = nrow(moran_summary))

# 整体统计
cat("\n整体统计：\n")
cat("  所有变量×轮次组合数        =", nrow(moran_df), "\n")
cat("  I > 0 的组合数              =",
    sum(moran_df$moran_I > 0, na.rm = TRUE),
    " (", round(mean(moran_df$moran_I > 0, na.rm = TRUE) * 100, 1), "%)\n")
cat("  p < 0.05 的组合数           =",
    sum(moran_df$p_value < 0.05, na.rm = TRUE),
    " (", round(mean(moran_df$p_value < 0.05, na.rm = TRUE) * 100, 1), "%)\n")
cat("  I 均值                     =",
    round(mean(moran_df$moran_I, na.rm = TRUE), 4), "\n")

write_csv_utf8(moran_df,
               file.path(out_dir, "32_moran_I_full.csv"))
write_csv_utf8(moran_summary,
               file.path(out_dir, "32b_moran_I_summary.csv"))

# =========================================================
# =========================================================
# 重新计算“多变量函数主成分的特征值及解释方差”表
# 依赖：eigenvalues, prop_each, cum_prop
# =========================================================

# 如果当前环境里还没有这三个对象，可从 mfpca_result 重新生成
if (!exists("eigenvalues")) {
  eigenvalues <- as.numeric(mfpca_result$values)
}
if (!exists("prop_each")) {
  prop_each <- eigenvalues / sum(eigenvalues)
}
if (!exists("cum_prop")) {
  cum_prop <- cumsum(prop_each)
}

# 生成表格数据
eigen_table_paper <- data.frame(
  主成分 = paste0("PC", seq_along(eigenvalues)),
  特征值 = round(eigenvalues, 3),
  方差解释率 = sprintf("%.2f\\%%", prop_each * 100),
  累计解释率 = sprintf("%.2f\\%%", cum_prop * 100),
  check.names = FALSE
)

# 打印查看
print(eigen_table_paper)

# 保存 CSV
write.csv(
  eigen_table_paper,
  file = file.path(out_dir, "eigenvalues_table_for_paper.csv"),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

cat("表格数据已保存：eigenvalues_table_for_paper.csv\n\n")

# =========================================================
# 输出完整 LaTeX 表格代码
# =========================================================
cat("\\begin{table}[htbp]\n")
cat("\\centering\n")
cat("\\caption{多变量函数主成分的特征值及解释方差。}\n")
cat("\\label{tab:eigenvalues}\n")
cat("\\begin{tabular}{cccc}\n")
cat("\\toprule\n")
cat("主成分 & 特征值 & 方差解释率 & 累计解释率 \\\\\n")
cat("\\midrule\n")

for (i in seq_len(nrow(eigen_table_paper))) {
  cat(
    eigen_table_paper[i, 1], " & ",
    sprintf("%.3f", eigen_table_paper[i, 2]), " & ",
    eigen_table_paper[i, 3], " & ",
    eigen_table_paper[i, 4], " \\\\\n",
    sep = ""
  )
}

cat("\\bottomrule\n")
cat("\\end{tabular}\n")
cat("\\end{table}\n")
#=========================================================
# =========================================================
# 重新计算论文中两个表格的数据
# 1) 各调查轮次在前三个主成分上的得分
# 2) 不同截断维数下的总体 RMSE 与相对降幅
# 依赖：scores, time_points, variables, standardized_array_list, mfpca_result
# =========================================================

# -----------------------------
# 辅助函数
# -----------------------------
extract_surface <- function(fun_obj_single) {
  x  <- fun_obj_single@X
  dx <- dim(x)
  if (length(dx) == 3) return(x[1, , ])
  if (length(dx) == 2) return(x)
  stop("无法识别 funData 对象的维度结构。")
}

# -----------------------------
# 检查对象
# -----------------------------
needed_objs <- c("scores", "time_points", "variables",
                 "standardized_array_list", "mfpca_result")
missing_objs <- needed_objs[!sapply(needed_objs, exists)]
if (length(missing_objs) > 0) {
  stop(paste("缺少对象：", paste(missing_objs, collapse = ", ")))
}

scores_mat <- as.matrix(scores)
if (ncol(scores_mat) < 3) {
  stop("scores 少于 3 列，无法生成 PC1-PC3 表格。")
}

# =========================================================
# 表 1：各调查轮次在前三个主成分上的得分
# =========================================================
scores_table <- data.frame(
  调查轮次 = as.character(time_points),
  `PC1 得分` = round(scores_mat[, 1], 3),
  `PC2 得分` = round(scores_mat[, 2], 3),
  `PC3 得分` = round(scores_mat[, 3], 3),
  check.names = FALSE
)

cat("\n==============================\n")
cat("表 1：各调查轮次在前三个主成分上的得分\n")
cat("==============================\n")
print(scores_table)

# 如需保存
write.csv(scores_table,
          file = "scores_table_recalculated.csv",
          row.names = FALSE,
          fileEncoding = "UTF-8")

# 如需直接输出 LaTeX 表格主体
cat("\nLaTeX 表 1 主体内容：\n")
for (i in seq_len(nrow(scores_table))) {
  cat(
    scores_table[i, 1], " & ",
    sprintf("%.3f", scores_table[i, 2]), " & ",
    sprintf("%.3f", scores_table[i, 3]), " & ",
    sprintf("%.3f", scores_table[i, 4]), " \\\\\n",
    sep = ""
  )
}

# =========================================================
# 表 2：不同截断维数下的总体 RMSE 与相对降幅
# =========================================================

# 先计算各变量的均值曲面
mean_surfaces <- vector("list", length(variables))
names(mean_surfaces) <- variables

for (j in seq_along(variables)) {
  mean_surfaces[[variables[j]]] <- apply(
    standardized_array_list[[variables[j]]],
    c(2, 3),
    mean,
    na.rm = TRUE
  )
}

M_use <- min(3, ncol(scores_mat))

rmse_list <- list()

for (M in seq_len(M_use)) {
  sse_all <- 0
  n_all   <- 0
  
  for (j in seq_along(variables)) {
    var_name     <- variables[j]
    obs_array    <- standardized_array_list[[var_name]]
    mean_surface <- mean_surfaces[[var_name]]
    
    for (i in seq_along(time_points)) {
      recon <- mean_surface
      
      for (m in seq_len(M)) {
        phi_m <- extract_surface(mfpca_result$functions[[j]][m])
        recon <- recon + scores_mat[i, m] * phi_m
      }
      
      diff_mat <- obs_array[i, , ] - recon
      sse_all  <- sse_all + sum(diff_mat^2, na.rm = TRUE)
      n_all    <- n_all + sum(!is.na(diff_mat))
    }
  }
  
  rmse_list[[M]] <- data.frame(
    M = M,
    RMSE = sqrt(sse_all / n_all)
  )
}

rmse_df <- do.call(rbind, rmse_list)
rmse_base <- rmse_df$RMSE[rmse_df$M == 1]

rmse_df$相对降幅 <- ifelse(
  rmse_df$M == 1,
  "---",
  sprintf("%.1f%%", (rmse_base - rmse_df$RMSE) / rmse_base * 100)
)

# 保留论文表格风格
rmse_table <- data.frame(
  `保留主成分个数 M` = rmse_df$M,
  RMSE = round(rmse_df$RMSE, 3),
  `相对降幅（较 M=1）` = rmse_df$相对降幅,
  check.names = FALSE
)

cat("\n==============================\n")
cat("表 2：不同截断维数下的总体 RMSE\n")
cat("==============================\n")
print(rmse_table)

# 如需保存
write.csv(rmse_table,
          file = "rmse_table_recalculated.csv",
          row.names = FALSE,
          fileEncoding = "UTF-8")

# 如需直接输出 LaTeX 表格主体
cat("\nLaTeX 表 2 主体内容：\n")
for (i in seq_len(nrow(rmse_table))) {
  cat(
    rmse_table[i, 1], " & ",
    sprintf("%.3f", rmse_table[i, 2]), " & ",
    rmse_table[i, 3], " \\\\\n",
    sep = ""
  )
}
#============================================================
# =========================================================
# SECTION XX. PC1 预警监测图
# 生成两张图：
# 1) 基于阈值的 PC1 分数监测图
# 2) EWMA 漂移检测图
# 依赖对象：scores, out_dir
# =========================================================

# =========================================================
# SECTION XX. PC1 预警监测图
# 生成两张图：
# 1) 基于阈值的 PC1 分数监测图
# 2) EWMA 漂移检测图
# 依赖对象：scores, out_dir
# =========================================================
https://chatgpt.com/g/g-p-69cddc69292081919f99777cf63ee6a6-mfpca-zhuan-li/c/69d8668c-0dec-839f-ad55-043b80cf4321