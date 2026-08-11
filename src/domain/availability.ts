export const availabilityKinds = [
  { value: "available", label: "Available" },
  { value: "unavailable", label: "Unavailable" },
] as const;

export type AvailabilityKind = (typeof availabilityKinds)[number]["value"];

export interface Availability {
  id: string;
  item_id: string;
  kind: AvailabilityKind;
  start_date: string;
  end_date: string;
}

export function validateAvailabilityDates(
  startDate: string,
  endDate: string,
): string | null {
  if (
    !/^\d{4}-\d{2}-\d{2}$/.test(startDate) ||
    !/^\d{4}-\d{2}-\d{2}$/.test(endDate)
  ) {
    return "Choose both a start date and an end date.";
  }
  if (startDate > endDate) {
    return "The end date must be on or after the start date.";
  }
  return null;
}

export function availabilityLabel(availability: Availability): string {
  const kind = availability.kind === "available" ? "Available" : "Unavailable";
  return availability.start_date === availability.end_date
    ? `${kind} on ${availability.start_date}`
    : `${kind} from ${availability.start_date} through ${availability.end_date}`;
}
