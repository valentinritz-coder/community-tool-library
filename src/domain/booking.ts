export interface BookingRequest {
  id: string;
  item_id: string;
  item_name: string;
  start_date: string;
  end_date: string;
  status: "requested";
  is_borrower: boolean;
  is_item_owner: boolean;
  borrower_label: "You" | "Community member";
}

export function validateBookingDates(
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
