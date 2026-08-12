export const moderationReasons = [
  { value: "inappropriate", label: "Inappropriate content" },
  { value: "misleading", label: "Misleading listing or behaviour" },
  { value: "unsafe", label: "Safety concern" },
  { value: "other", label: "Other" },
] as const;

export type ModerationReason = (typeof moderationReasons)[number]["value"];

export interface ModerationReport {
  id: string;
  target_type: "item" | "counterparty";
  target_label: string;
  item_id: string | null;
  reason: ModerationReason;
  note: string | null;
  status: "open" | "handled";
  created_at: string;
  action_taken: string | null;
}

export function moderationReasonLabel(reason: ModerationReason): string {
  return (
    moderationReasons.find((entry) => entry.value === reason)?.label ?? reason
  );
}
