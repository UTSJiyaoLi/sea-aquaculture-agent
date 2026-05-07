import { BatchSummary } from "../lib/types";

export function BatchSelector({
  batches,
  value,
  onChange,
}: {
  batches: BatchSummary[];
  value: string;
  onChange: (value: string) => void;
}) {
  return (
    <label className="label">
      批次
      <select value={value} onChange={(event) => onChange(event.target.value)}>
        {batches.map((batch) => (
          <option key={batch.batch_id} value={batch.batch_id}>
            {batch.batch_id} · {batch.cage_id}
          </option>
        ))}
      </select>
    </label>
  );
}
