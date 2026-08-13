export interface BookingRequest {
  id: string;
  item_id: string;
  item_name: string;
  start_date: string;
  end_date: string;
  status:
    | "requested"
    | "accepted"
    | "refused"
    | "checked_out"
    | "returned"
    | "cancelled";
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
  checked_out: "Checked out",
  returned: "Returned",
  cancelled: "Cancelled",
};

export function canCancelBooking(booking: BookingRequest): boolean {
  return (
    (booking.status === "requested" && booking.is_borrower) ||
    (booking.status === "accepted" &&
      (booking.is_borrower || booking.is_item_owner))
  );
}

export type ConditionPhase = "before" | "after";

export interface ConditionReport {
  id: string;
  booking_id: string;
  phase: ConditionPhase;
  photo_path: string;
  created_at: string;
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
