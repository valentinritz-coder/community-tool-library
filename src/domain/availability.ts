export interface Availability {
  id: string;
  item_id: string;
  start_date: string;
  end_date: string;
}

// Availability is allow-list based: a calendar date outside every range is unavailable.
export function isDateAvailable(
  availabilities: Availability[],
  calendarDate: string,
): boolean {
  return availabilities.some(
    ({ start_date, end_date }) =>
      start_date <= calendarDate && calendarDate <= end_date,
  );
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
  return availability.start_date === availability.end_date
    ? `Available on ${availability.start_date}`
    : `Available from ${availability.start_date} through ${availability.end_date}`;
}
