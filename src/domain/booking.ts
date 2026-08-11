export interface BookingRequest {
  id: string;
  item_id: string;
  item_name: string;
  start_date: string;
  end_date: string;
  status: "requested" | "accepted" | "refused";
  is_borrower: boolean;
  is_item_owner: boolean;
  can_decide: boolean;
  borrower_label: "You" | "Community member";
}

export interface BookingContact {
  booking_id: string;
  counterparty_email: string;
}

export const bookingStatusLabel: Record<BookingRequest["status"], string> = {
  requested: "Requested",
  accepted: "Accepted",
  refused: "Refused",
};

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
