import numpy as np
from scipy.integrate import odeint
import matplotlib.pyplot as plt

# =========================
# 1. 参数设置（对应说明书表 1）
# =========================

# 鱼类相关
T_opt = 25.0                # 最佳温度 (°C)
mu0 = 5e-5                  # 基础死亡率 (1/天)
mu_T = 5e-5                 # 死亡率温度系数 (1/°C²/天)
g_max = 0.035               # 最大生长率 (1/天)
g_T = 0.026                 # 生长率温度系数 (1/°C²)
W_max = 600              # 最大个体重量 (g)

# 投饵与饲料
f_feed = 0.05               # 投饵率 (1/天)
N_feed = 0.08               # 饲料氮含量 (g N / g 饲料)
P_feed = 0.015              # 饲料磷含量 (g P / g 饲料)
p_unfed = 0.05              # 未食用饲料比例
eta_assim = 0.85            # 饲料吸收效率

# 系统体积与水交换
V = 3_000_000.0             # 体积 (L)
Q_over_V = 15.0             # 水交换率 (1/天)


# 叶绿素/藻类
r_Cmax = 0.6                # 最大叶绿素生长率 (1/天)
alpha_CT = 0.04             # 叶绿素温度系数 (1/°C²)
K_N = 2.0                   # 氮半饱和常数 (mg/L)
K_P = 0.1                   # 磷半饱和常数 (mg/L)
d_C = 0.15                  # 藻类衰减率 (1/天)

# 溶解氧与分解
r_DO = 0.5                  # 产氧率 (mg O2 / mg C)
q_fish = 0.20               # 鱼类耗氧率 (mg O2 / g 鱼 / 天)
q_N = 0.015                 # 氮分解耗氧率 (mg O2 / mg N / 天)
DO_in = 9.0                 # 交换水溶解氧 (mg/L)
k_N = 0.02                  # 氮降解率 (1/天)
k_P = 0.015                 # 磷降解率 (1/天)

# 藻类化学计量
N_C = 0.08                  # 叶绿素氮含量 (mg N / mg C)
P_C = 0.015                 # 叶绿素磷含量 (mg P / mg C)

# 背景/外海浓度（简单取初始值，可按需要修改）
TN_in = 0.5                 # 外海 TN (mg/L)
TP_in = 0.5                 # 外海 TP (mg/L)
C_in = 5.0                  # 外海叶绿素 (mg/L)

# 初始条件（说明书中给出）
N0 = 65000.0                # 初始尾数 (尾)
W0 = 10.0                   # 初始单体体重 (g)
C0 = 5.0                    # 初始叶绿素 (mg/L)
TN0 = 0.5                   # 初始 TN (mg/L)
TP0 = 0.5                   # 初始 TP (mg/L)
DO0 = 8.0                   # 初始 DO (mg/L)
E_N0 = 0.0                  # 累积总氮排放 (kg)
E_P0 = 0.0                  # 累积总磷排放 (kg)

# 状态向量 y = [N, W, TN, TP, C, DO, E_N, E_P]
y0 = [N0, W0, TN0, TP0, C0, DO0, E_N0, E_P0]

# 模拟时间：0–180 天
t_end = 180.0
t = np.linspace(0.0, t_end, 181)  # 每天一个点

# =========================
# 2. 温度函数（图1）
# =========================
def make_temperature_series(t_array, seed=42):
    """
    在 0~180 天内只出现一次“先升后降”的变化，
    在此基础上叠加平滑噪声，模拟真实 180 天温度变化。
    """
    T_min = 20.0    # 基本最低温度
    T_max = 30.0    # 基本最高温度

    # 半正弦主趋势：0 -> pi
    x = t_array / t_end
    T_base = T_min + (T_max - T_min) * np.sin(np.pi * x)

    # 加一点平滑噪声：先生成白噪声，再用滑动平均平滑
    rng = np.random.default_rng(seed)
    noise_raw = rng.normal(loc=0.0, scale=0.8, size=len(t_array))  # 原始噪声，标准差约 0.8 ℃

    # 简单滑动平均滤波，制造相关噪声（变得更平滑）
    window = 7
    kernel = np.ones(window) / window
    noise_smooth = np.convolve(noise_raw, kernel, mode='same')

    T_series = T_base + noise_smooth

    # 限制到一个合理范围，比如 18~32 ℃
    T_series = np.clip(T_series, T_min - 2.0, T_max + 2.0)

    return T_series

# 预生成整段 180 天的温度序列（有噪声）
T_series = make_temperature_series(t)

def temperature(t_day):
    """
    给定任意 t_day（标量或数组），通过线性插值返回温度。
    这样在 ODE 求解时，每次调用都是确定性的（不会重复随机）。
    """
    return np.interp(t_day, t, T_series)



# =========================
# 3. 微分方程系统
#    状态向量 y = [N, W, TN, TP, C, DO, E_N, E_P]
# =========================

def rhs(y, t):
    N, W, TN, TP, C, DO, E_N, E_P = y

    # 温度
    T = temperature(t)

    # --- 鱼群数量 N(t) ---
    # 死亡率 μ(T) = μ0 + μ_T (T - T_opt)^2
    mu_Temp = mu0 + mu_T * (T - T_opt) ** 2
    dNdt = -mu_Temp * N

    # --- 单体鱼体重 W(t) ---
    # Logistic 生长，温度修正 g(T) = g_max * exp(-g_T (T - T_opt)^2)
    g_Temp = g_max * np.exp(-g_T * (T - T_opt) ** 2)
    dWdt = g_Temp * W * (1.0 - W / W_max)

    # --- 派生量：总生物量与投饵量 ---
    B = N * W                 # 生物量 (g)
    F = f_feed * B            # 投饵量 (g 饲料/天)

    # --- 饲料引入的 N、P（进入水体部分） ---
    # 未食用 + 已食用中未吸收部分
    frac_to_water = p_unfed + (1.0 - p_unfed) * (1.0 - eta_assim)
    N_input_g_per_day = F * frac_to_water * N_feed  # g N/天
    P_input_g_per_day = F * frac_to_water * P_feed  # g P/天

    # 转换为浓度变化 (mg/L/天)
    N_input_mgL = N_input_g_per_day * 1000.0 / V
    P_input_mgL = P_input_g_per_day * 1000.0 / V

    # --- 叶绿素/藻类 C(t) ---
    # 温度因子 + 营养限制 Monod
    fT_C = np.exp(-alpha_CT * (T - T_opt) ** 2)
    L_N = TN / (K_N + TN) if TN > 0.0 else 0.0
    L_P = TP / (K_P + TP) if TP > 0.0 else 0.0
    L_lim = min(L_N, L_P)
    growth_C = r_Cmax * fT_C * L_lim * C        # 生长项 (mgC/L/天)
    loss_C = d_C * C                            # 自然损失
    exchange_C = Q_over_V * (C - C_in)          # 水交换损失

    dCdt = growth_C - loss_C - exchange_C

    # --- 总氮 TN(t) ---
    uptake_N = N_C * growth_C                   # 被藻类同化的 N (mgN/L/天)
    degradation_N = k_N * TN                    # 降解/移除
    exchange_N = Q_over_V * (TN - TN_in)        # 随水交换流出 (mg/L/天)

    dTNdt = N_input_mgL - uptake_N - degradation_N - exchange_N

    # --- 总磷 TP(t) ---
    uptake_P = P_C * growth_C
    degradation_P = k_P * TP
    exchange_P = Q_over_V * (TP - TP_in)

    dTPdt = P_input_mgL - uptake_P - degradation_P - exchange_P

    # --- 溶解氧 DO(t) ---
    prod_DO = r_DO * growth_C                   # 藻类光合作用产氧
    cons_fish = q_fish * B / V                  # 鱼类呼吸耗氧 (mg/L/天)
    cons_N = q_N * TN                           # 氮分解耗氧 (mg/L/天)
    exchange_DO = Q_over_V * (DO - DO_in)       # 水交换 (mg/L/天)

    dDOdt = prod_DO - cons_fish - cons_N - exchange_DO

    # --- 累积排放 E_N, E_P ---
    # 只累积“从网箱流出”的部分（exchange_N > 0 时）
    E_N_flux_mg_per_day = max(exchange_N, 0.0) * V   # mg/天
    E_P_flux_mg_per_day = max(exchange_P, 0.0) * V   # mg/天

    dE_Ndt = E_N_flux_mg_per_day * 1e-6             # 转为 kg/天
    dE_Pdt = E_P_flux_mg_per_day * 1e-6

    return [dNdt, dWdt, dTNdt, dTPdt, dCdt, dDOdt, dE_Ndt, dE_Pdt]


# =========================
# 4. 数值求解
# =========================

sol = odeint(rhs, y0, t)

N = sol[:, 0]
W = sol[:, 1]
TN = sol[:, 2]
TP = sol[:, 3]
C = sol[:, 4]
DO = sol[:, 5]
E_N = sol[:, 6]
E_P = sol[:, 7]

# 派生量：生物量、投饵量、温度
B = N * W          # 生物量 (g)
F = f_feed * B     # 投饵量 (g/天)
T_series = temperature(t)


# =========================
# 5. 画图（对应 图1–图11）
# =========================

# 中文显示（如果没有黑体字体，可以注释掉这两行）
plt.rcParams['font.sans-serif'] = ['SimHei']   # 支持中文
plt.rcParams['axes.unicode_minus'] = False     # 负号正常显示

# 图1：温度
plt.figure(figsize=(6, 4))
plt.plot(t, T_series)
plt.xlabel("时间 (天)")
plt.ylabel("温度 (°C)")
plt.title("图1 温度随时间变化")
plt.grid(True)

# 图2：鱼群数量
plt.figure(figsize=(6, 4))
plt.plot(t, N)
plt.xlabel("时间 (天)")
plt.ylabel("鱼群数量 N (尾)")
plt.title("图2 鱼群数量随时间变化")
plt.grid(True)

# 图3：单体鱼体重
plt.figure(figsize=(6, 4))
plt.plot(t, W)
plt.xlabel("时间 (天)")
plt.ylabel("单体体重 W (g)")
plt.title("图3 单体鱼体重随时间变化")
plt.grid(True)

# 图4：总生物量
plt.figure(figsize=(6, 4))
plt.plot(t, B / 1000.0)
plt.xlabel("时间 (天)")
plt.ylabel("总生物量 B (kg)")
plt.title("图4 总生物量随时间变化")
plt.grid(True)

# 图5：投饵量
plt.figure(figsize=(6, 4))
plt.plot(t, F / 1000.0)
plt.xlabel("时间 (天)")
plt.ylabel("投饵量 F (kg/天)")
plt.title("图5 投饵量随时间变化")
plt.grid(True)

# 图6：叶绿素浓度
plt.figure(figsize=(6, 4))
plt.plot(t, C)
plt.xlabel("时间 (天)")
plt.ylabel("叶绿素 C (mg/L)")
plt.title("图6 叶绿素浓度随时间变化")
plt.grid(True)

# 图7：溶解氧浓度
plt.figure(figsize=(6, 4))
plt.plot(t, DO)
plt.xlabel("时间 (天)")
plt.ylabel("溶解氧 DO (mg/L)")
plt.title("图7 溶解氧浓度随时间变化")
plt.axhline(5.0, linestyle="--", label="DO = 5 mg/L")
plt.legend()
plt.grid(True)

# 图8：总氮浓度
plt.figure(figsize=(6, 4))
plt.plot(t, TN)
plt.xlabel("时间 (天)")
plt.ylabel("总氮 TN (mg/L)")
plt.title("图8 总氮浓度随时间变化")
plt.grid(True)

# 图9：总磷浓度
plt.figure(figsize=(6, 4))
plt.plot(t, TP)
plt.xlabel("时间 (天)")
plt.ylabel("总磷 TP (mg/L)")
plt.title("图9 总磷浓度随时间变化")
plt.grid(True)

# 图10：累积总氮排放量
plt.figure(figsize=(6, 4))
plt.plot(t, E_N)
plt.xlabel("时间 (天)")
plt.ylabel("累积总氮排放 E_N (kg)")
plt.title("图10 累积总氮排放量随时间变化")
plt.grid(True)

# 图11：累积总磷排放量
plt.figure(figsize=(6, 4))
plt.plot(t, E_P)
plt.xlabel("时间 (天)")
plt.ylabel("累积总磷排放 E_P (kg)")
plt.title("图11 累积总磷排放量随时间变化")
plt.grid(True)

plt.show()
