import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { ItemSection } from "./item-section";

const query = {
  select: vi.fn(() => query),
  order: vi.fn().mockResolvedValue({ data: [], error: null }),
  insert: vi.fn().mockResolvedValue({ error: null }),
  update: vi.fn(() => query),
  delete: vi.fn(() => query),
  eq: vi.fn().mockResolvedValue({ error: null }),
};
const rpc = vi.fn().mockResolvedValue({ data: [], error: null });

const createSignedUrl = vi.fn((path: string) =>
  Promise.resolve({
    data: { signedUrl: `https://private.test/${path}?token=temporary` },
    error: null,
  }),
);

vi.mock("../infrastructure/supabase-browser", () => ({
  getSupabaseBrowserClient: () => ({
    from: vi.fn(() => query),
    rpc,
    storage: {
      from: vi.fn(() => ({
        createSignedUrl,
        upload: vi.fn().mockResolvedValue({ error: null }),
      })),
    },
  }),
}));

describe("ItemSection", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    query.order.mockResolvedValue({ data: [], error: null });
    rpc.mockResolvedValue({ data: [], error: null });
  });

  const community = {
    id: "community-a",
    name: "Riverside",
    join_code: "join-code",
  };

  function inventoryRpc() {
    rpc.mockImplementation((name: string) =>
      Promise.resolve({
        data:
          name === "browse_community_inventory"
            ? [
                {
                  id: "item-a",
                  community_id: "community-a",
                  name: "Cordless drill",
                  category: "small_diy",
                  description: "Compact drill",
                  photo_path: "item-a/photo.jpg",
                  is_free: true,
                  price_per_day_cents: null,
                  is_owned: false,
                  availability_summary: "Available tomorrow",
                },
              ]
            : [],
        error: null,
      }),
    );
  }

  it("submits the labelled item report reason and note and announces success", async () => {
    inventoryRpc();
    render(<ItemSection communities={[community]} currentUserId="member-a" />);
    fireEvent.click(await screen.findByText("Report item"));
    expect(screen.getByLabelText("Reason")).toBeRequired();
    expect(screen.getByLabelText(/Additional note/)).toHaveAttribute(
      "maxlength",
      "500",
    );
    fireEvent.change(screen.getByLabelText("Reason"), {
      target: { value: "unsafe" },
    });
    fireEvent.change(screen.getByLabelText(/Additional note/), {
      target: { value: "Loose guard" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Submit report" }));
    await waitFor(() =>
      expect(rpc).toHaveBeenCalledWith("submit_item_report", {
        target_item_id: "item-a",
        report_reason: "unsafe",
        report_note: "Loose guard",
      }),
    );
    expect(await screen.findByText("Report submitted.")).toHaveAttribute(
      "role",
      "status",
    );
  });

  it("announces report errors and prevents a duplicate submit while pending", async () => {
    let finish:
      | ((value: { data: null; error: { message: string } }) => void)
      | undefined;
    inventoryRpc();
    render(<ItemSection communities={[community]} currentUserId="member-a" />);
    fireEvent.click(await screen.findByText("Report item"));
    rpc.mockImplementationOnce(
      () =>
        new Promise((resolve) => {
          finish = resolve;
        }),
    );
    const submit = screen.getByRole("button", { name: "Submit report" });
    fireEvent.click(submit);
    fireEvent.click(submit);
    expect(submit).toBeDisabled();
    expect(
      rpc.mock.calls.filter(([name]) => name === "submit_item_report"),
    ).toHaveLength(1);
    finish?.({ data: null, error: { message: "Open report already exists" } });
    expect(await screen.findByRole("alert")).toHaveTextContent(
      "Open report already exists",
    );
  });

  it("shows moderation statuses and sends handled and item-hide actions", async () => {
    rpc.mockImplementation((name: string) =>
      Promise.resolve({
        data:
          name === "list_moderation_reports"
            ? [
                {
                  id: "report-item",
                  target_type: "item",
                  target_label: "Drill",
                  item_id: "item-a",
                  reason: "unsafe",
                  note: null,
                  status: "open",
                  created_at: "2026-08-12T00:00:00Z",
                  action_taken: null,
                },
                {
                  id: "report-user",
                  target_type: "counterparty",
                  target_label: "Transaction counterparty",
                  item_id: null,
                  reason: "other",
                  note: null,
                  status: "handled",
                  created_at: "2026-08-11T00:00:00Z",
                  action_taken: "reviewed",
                },
              ]
            : [],
        error: null,
      }),
    );
    render(
      <ItemSection
        communities={[community]}
        currentUserId="admin-a"
        adminCommunityIds={["community-a"]}
      />,
    );
    expect(await screen.findByText("Status: Open")).toBeInTheDocument();
    expect(screen.getByText("Status: Handled")).toBeInTheDocument();
    expect(screen.getAllByRole("button", { name: "Hide item" })).toHaveLength(
      1,
    );
    fireEvent.click(screen.getByRole("button", { name: "Mark handled" }));
    await waitFor(() =>
      expect(rpc).toHaveBeenCalledWith("handle_moderation_report", {
        target_report_id: "report-item",
      }),
    );
  });

  it("hides an item through the report-scoped moderation RPC", async () => {
    rpc.mockImplementation((name: string) =>
      Promise.resolve({
        data:
          name === "list_moderation_reports"
            ? [
                {
                  id: "report-item",
                  target_type: "item",
                  target_label: "Drill",
                  item_id: "item-a",
                  reason: "unsafe",
                  note: null,
                  status: "open",
                  created_at: "2026-08-12T00:00:00Z",
                  action_taken: null,
                },
              ]
            : [],
        error: null,
      }),
    );
    render(
      <ItemSection
        communities={[community]}
        currentUserId="admin-a"
        adminCommunityIds={["community-a"]}
      />,
    );
    fireEvent.click(await screen.findByRole("button", { name: "Hide item" }));
    await waitFor(() =>
      expect(rpc).toHaveBeenCalledWith("hide_reported_item", {
        target_report_id: "report-item",
      }),
    );
  });

  it("offers a labelled, low-risk mobile item form", () => {
    render(
      <ItemSection
        communities={[
          { id: "community-a", name: "Riverside", join_code: "join-code" },
        ]}
        currentUserId="member-a"
      />,
    );

    expect(screen.getAllByLabelText("Community")).toHaveLength(2);
    expect(screen.getByLabelText("Item name")).toBeRequired();
    expect(screen.getByLabelText("Item category")).toHaveTextContent(
      "Small, low-risk DIY",
    );
    expect(screen.queryByRole("option", { name: /chainsaw/i })).toBeNull();
    expect(screen.getByLabelText(/Item photo/)).toHaveAttribute(
      "accept",
      "image/jpeg,image/png,image/webp",
    );
    expect(screen.getByRole("radio", { name: "Free loan" })).toBeChecked();
    expect(
      screen.getByRole("button", { name: "List item" }),
    ).toBeInTheDocument();
  });

  it("associates a new-item price error with its field", async () => {
    render(
      <ItemSection
        communities={[
          { id: "community-a", name: "Riverside", join_code: "join-code" },
        ]}
        currentUserId="member-a"
      />,
    );
    fireEvent.click(screen.getByRole("radio", { name: "Price per day" }));
    const price = document.getElementById("item-price") as HTMLInputElement;
    expect(price).toBeInstanceOf(HTMLInputElement);
    fireEvent.change(price, { target: { value: "invalid" } });
    Object.defineProperty(screen.getByLabelText(/Item photo/), "files", {
      configurable: true,
      value: [new File(["photo"], "photo.jpg", { type: "image/jpeg" })],
    });
    const form = price.closest("form");
    expect(form).not.toBeNull();
    fireEvent.submit(form!);

    expect(await screen.findByRole("alert")).toHaveTextContent(
      "Enter a daily price between 0.01 and 1000.00.",
    );
    const invalidPrice = document.getElementById("item-price");
    expect(invalidPrice).toHaveAttribute("aria-invalid", "true");
    expect(invalidPrice).toHaveAttribute("aria-errormessage", "item-message");
  });

  it("associates edit price and replacement-photo errors with their fields", async () => {
    query.order
      .mockResolvedValueOnce({
        data: [
          {
            id: "item-a",
            community_id: "community-a",
            owner_id: "member-a",
            name: "Drill",
            category: "small_diy",
            description: "Small drill",
            photo_path: "item-a/photo.jpg",
            is_free: false,
            price_per_day_cents: 100,
            archived: false,
            photo_uploaded: true,
          },
        ],
        error: null,
      })
      .mockResolvedValueOnce({ data: [], error: null });
    render(
      <ItemSection
        communities={[
          { id: "community-a", name: "Riverside", join_code: "join-code" },
        ]}
        currentUserId="member-a"
      />,
    );
    fireEvent.click(await screen.findByText("Edit item"));
    const editForm = screen
      .getByLabelText("Price per day (leave blank for free)")
      .closest("form");
    expect(editForm).not.toBeNull();
    const price = screen.getByLabelText("Price per day (leave blank for free)");
    fireEvent.change(price, { target: { value: "invalid" } });
    fireEvent.submit(editForm!);
    expect(await screen.findByRole("alert")).toHaveTextContent(
      "Enter a daily price between 0.01 and 1000.00.",
    );
    expect(price).toHaveAttribute("aria-errormessage", "item-message");

    fireEvent.change(price, { target: { value: "1.00" } });
    const replacement = screen.getByLabelText(/Replace photo/);
    const invalidPhoto = new File(["photo"], "photo.gif", {
      type: "image/gif",
    });
    const NativeFormData = FormData;
    vi.stubGlobal(
      "FormData",
      class extends NativeFormData {
        override get(name: string) {
          return name === "photo" ? invalidPhoto : super.get(name);
        }
      },
    );
    fireEvent.submit(editForm!);
    expect(await screen.findByRole("alert")).toHaveTextContent(
      "The replacement must use the same JPEG, PNG, or WebP format and be 5 MB or smaller.",
    );
    expect(replacement).toHaveAttribute("aria-invalid", "true");
    expect(replacement).toHaveAttribute("aria-errormessage", "item-message");
    vi.unstubAllGlobals();
  });

  it("shows searchable inventory details and a clear no-result state", async () => {
    rpc.mockResolvedValueOnce({
      data: [
        {
          id: "item-a",
          community_id: "community-a",
          name: "Cordless screwdriver",
          category: "small_diy",
          description: "Compact and easy to carry",
          photo_path: "item-a/photo.jpg",
          is_free: false,
          price_per_day_cents: 450,
          is_owned: false,
          availability_summary:
            "Available only from 2026-08-12 through 2026-08-15; on 2026-08-18",
        },
      ],
      error: null,
    });

    render(
      <ItemSection
        communities={[
          { id: "community-a", name: "Riverside", join_code: "join-code" },
        ]}
        currentUserId="member-a"
      />,
    );

    expect(
      await screen.findByRole("heading", { name: "Cordless screwdriver" }),
    ).toBeInTheDocument();
    expect(screen.getByText("1 item shown.")).toHaveAttribute("role", "status");
    expect(
      screen.getByText("Small, low-risk DIY", { selector: "p" }),
    ).toBeInTheDocument();
    expect(screen.getByText("4.50 per day")).toBeInTheDocument();
    expect(screen.getByText("Owner: Community member")).toBeInTheDocument();
    expect(
      screen.getByText(
        "Availability: Available only from 2026-08-12 through 2026-08-15; on 2026-08-18",
      ),
    ).toBeInTheDocument();
    expect(
      screen.getByAltText("Photo of Cordless screwdriver"),
    ).toHaveAttribute("src", expect.stringContaining("token=temporary"));

    fireEvent.change(screen.getByLabelText("Search inventory"), {
      target: { value: "leisure" },
    });
    await waitFor(() =>
      expect(
        screen.getByText(/No items match your search/),
      ).toBeInTheDocument(),
    );
  });

  it("provides labelled owner controls, adds a range, and reports date errors", async () => {
    query.order
      .mockResolvedValueOnce({
        data: [
          {
            id: "item-a",
            community_id: "community-a",
            owner_id: "member-a",
            name: "Drill",
            category: "small_diy",
            description: "Small drill",
            photo_path: "item-a/photo.jpg",
            is_free: true,
            price_per_day_cents: null,
            archived: false,
            photo_uploaded: true,
          },
        ],
        error: null,
      })
      .mockResolvedValueOnce({ data: [], error: null });

    render(
      <ItemSection
        communities={[
          { id: "community-a", name: "Riverside", join_code: "join-code" },
        ]}
        currentUserId="member-a"
      />,
    );

    expect(
      await screen.findByText("No availability ranges set."),
    ).toBeInTheDocument();
    expect(
      screen.getByText(/The item is unavailable by default/),
    ).toBeInTheDocument();
    const start = screen.getByLabelText("Start date (included)");
    const end = screen.getByLabelText("End date (included)");
    fireEvent.change(start, { target: { value: "2026-08-15" } });
    fireEvent.change(end, { target: { value: "2026-08-12" } });
    fireEvent.click(
      screen.getByRole("button", { name: "Add availability range" }),
    );
    expect(await screen.findByRole("alert")).toHaveTextContent(
      "The end date must be on or after the start date.",
    );
    expect(start).toHaveAttribute("aria-invalid", "true");
    expect(end).toHaveAttribute("aria-errormessage", "item-message");
    expect(query.insert).not.toHaveBeenCalled();

    fireEvent.change(end, { target: { value: "2026-08-15" } });
    fireEvent.click(
      screen.getByRole("button", { name: "Add availability range" }),
    );
    await waitFor(() =>
      expect(query.insert).toHaveBeenCalledWith({
        item_id: "item-a",
        start_date: "2026-08-15",
        end_date: "2026-08-15",
      }),
    );
  });

  it("states honestly when borrower-facing availability is not configured", async () => {
    rpc.mockResolvedValueOnce({
      data: [
        {
          id: "item-a",
          community_id: "community-a",
          name: "Drill",
          category: "small_diy",
          description: "Small drill",
          photo_path: "item-a/photo.jpg",
          is_free: true,
          price_per_day_cents: null,
          is_owned: false,
          availability_summary:
            "Unavailable: the owner has not added available dates.",
        },
      ],
      error: null,
    });
    render(
      <ItemSection
        communities={[
          { id: "community-a", name: "Riverside", join_code: "join-code" },
        ]}
        currentUserId="member-a"
      />,
    );
    expect(
      await screen.findByText(
        "Availability: Unavailable: the owner has not added available dates.",
      ),
    ).toBeInTheDocument();
  });

  it("distinguishes an empty inventory from a search with no matches", async () => {
    render(
      <ItemSection
        communities={[
          { id: "community-a", name: "Riverside", join_code: "join-code" },
        ]}
        currentUserId="member-a"
      />,
    );

    expect(
      await screen.findByText(/does not have any listed items yet/),
    ).toBeInTheDocument();
  });

  it("submits labelled booking dates and confirms Requested status", async () => {
    rpc.mockImplementation((name: string) => {
      if (name === "browse_community_inventory") {
        return Promise.resolve({
          data: [
            {
              id: "item-a",
              community_id: "community-a",
              name: "Drill",
              category: "small_diy",
              description: "Small drill",
              photo_path: "item-a/photo.jpg",
              is_free: true,
              price_per_day_cents: null,
              is_owned: false,
              availability_summary: "Available only on 2026-08-15",
            },
          ],
          error: null,
        });
      }
      return Promise.resolve({ data: [], error: null });
    });

    render(
      <ItemSection
        communities={[
          { id: "community-a", name: "Riverside", join_code: "join-code" },
        ]}
        currentUserId="member-a"
      />,
    );

    const start = await screen.findByLabelText("Start date");
    const end = screen.getByLabelText("End date");
    fireEvent.change(start, { target: { value: "2026-08-15" } });
    fireEvent.change(end, { target: { value: "2026-08-15" } });
    fireEvent.click(
      screen.getByRole("button", { name: "Request reservation" }),
    );

    await waitFor(() =>
      expect(rpc).toHaveBeenCalledWith("request_booking", {
        target_item_id: "item-a",
        requested_start_date: "2026-08-15",
        requested_end_date: "2026-08-15",
      }),
    );
    expect(
      await screen.findByText(
        "Reservation request created with Requested status.",
      ),
    ).toBeInTheDocument();
  });

  it("shows an understandable unavailable error", async () => {
    rpc.mockImplementation((name: string) => {
      if (name === "browse_community_inventory") {
        return Promise.resolve({
          data: [
            {
              id: "item-a",
              community_id: "community-a",
              name: "Drill",
              category: "small_diy",
              description: "Small drill",
              photo_path: "item-a/photo.jpg",
              is_free: true,
              price_per_day_cents: null,
              is_owned: false,
              availability_summary: "Available only on 2026-08-15",
            },
          ],
          error: null,
        });
      }
      if (name === "request_booking") {
        return Promise.resolve({
          data: null,
          error: new Error("The requested dates are not fully available"),
        });
      }
      return Promise.resolve({ data: [], error: null });
    });
    render(
      <ItemSection
        communities={[
          { id: "community-a", name: "Riverside", join_code: "join-code" },
        ]}
        currentUserId="member-a"
      />,
    );
    fireEvent.change(await screen.findByLabelText("Start date"), {
      target: { value: "2026-08-16" },
    });
    fireEvent.change(screen.getByLabelText("End date"), {
      target: { value: "2026-08-16" },
    });
    fireEvent.click(
      screen.getByRole("button", { name: "Request reservation" }),
    );
    expect(
      await screen.findByText(/Those dates are not fully available/),
    ).toBeInTheDocument();
  });

  it("shows privacy-safe owner requests with decision actions", async () => {
    rpc.mockResolvedValueOnce({ data: [], error: null }).mockResolvedValueOnce({
      data: [
        {
          id: "booking-a",
          item_id: "item-a",
          item_name: "Drill",
          start_date: "2026-08-15",
          end_date: "2026-08-16",
          status: "requested",
          is_borrower: false,
          is_item_owner: true,
          can_decide: true,
          borrower_label: "Community member",
        },
      ],
      error: null,
    });
    render(
      <ItemSection
        communities={[
          { id: "community-a", name: "Riverside", join_code: "join-code" },
        ]}
        currentUserId="owner-a"
      />,
    );
    expect(
      await screen.findByText("Requested by: Community member"),
    ).toBeInTheDocument();
    expect(screen.getByText("Status: Requested")).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "Accept reservation for Drill" }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "Refuse reservation for Drill" }),
    ).toBeInTheDocument();
    expect(screen.queryByText(/@|phone|pickup/i)).toBeNull();
  });

  it("shows terminal booking statuses and accepted contact without actions", async () => {
    rpc.mockImplementation((name: string) => {
      if (name === "list_booking_requests") {
        return Promise.resolve({
          data: [
            {
              id: "booking-a",
              item_id: "item-a",
              item_name: "Drill",
              start_date: "2026-08-15",
              end_date: "2026-08-16",
              status: "accepted",
              is_borrower: true,
              is_item_owner: false,
              can_decide: false,
              borrower_label: "You",
            },
            {
              id: "booking-b",
              item_id: "item-b",
              item_name: "Sander",
              start_date: "2026-08-20",
              end_date: "2026-08-20",
              status: "refused",
              is_borrower: true,
              is_item_owner: false,
              can_decide: false,
              borrower_label: "You",
            },
          ],
          error: null,
        });
      }
      if (name === "list_accepted_booking_contacts") {
        return Promise.resolve({
          data: [
            {
              booking_id: "booking-a",
              counterparty_email: "owner@example.test",
            },
          ],
          error: null,
        });
      }
      return Promise.resolve({ data: [], error: null });
    });
    render(
      <ItemSection
        communities={[
          { id: "community-a", name: "Riverside", join_code: "join-code" },
        ]}
        currentUserId="borrower-a"
      />,
    );
    expect(await screen.findByText("Status: Accepted")).toBeInTheDocument();
    expect(screen.getByText("Status: Refused")).toBeInTheDocument();
    expect(
      screen.getByText("Contact email: owner@example.test"),
    ).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /accept|refuse/i })).toBeNull();
  });

  it("keeps terminal bookings for the item owner without decision actions", async () => {
    rpc.mockImplementation((name: string) => {
      if (name === "list_booking_requests") {
        return Promise.resolve({
          data: [
            {
              id: "booking-a",
              item_id: "item-a",
              item_name: "Drill",
              start_date: "2026-08-15",
              end_date: "2026-08-16",
              status: "accepted",
              is_borrower: false,
              is_item_owner: true,
              can_decide: false,
              borrower_label: "Community member",
            },
          ],
          error: null,
        });
      }
      return Promise.resolve({ data: [], error: null });
    });

    render(
      <ItemSection
        communities={[
          { id: "community-a", name: "Riverside", join_code: "join-code" },
        ]}
        currentUserId="owner-a"
      />,
    );

    expect(await screen.findByText("Status: Accepted")).toBeInTheDocument();
    expect(
      screen.getByText("Requested by: Community member"),
    ).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /accept|refuse/i })).toBeNull();
  });

  it("uses the decision RPC and refreshes authoritative status", async () => {
    let decided = false;
    rpc.mockImplementation((name: string, parameters?: unknown) => {
      if (name === "list_booking_requests") {
        return Promise.resolve({
          data: [
            {
              id: "booking-a",
              item_id: "item-a",
              item_name: "Drill",
              start_date: "2026-08-15",
              end_date: "2026-08-16",
              status: decided ? "accepted" : "requested",
              is_borrower: false,
              is_item_owner: true,
              can_decide: true,
              borrower_label: "Community member",
            },
          ],
          error: null,
        });
      }
      if (name === "decide_booking") {
        expect(parameters).toEqual({
          target_booking_id: "booking-a",
          decision: "accepted",
        });
        decided = true;
      }
      return Promise.resolve({ data: [], error: null });
    });
    render(
      <ItemSection
        communities={[
          { id: "community-a", name: "Riverside", join_code: "join-code" },
        ]}
        currentUserId="owner-a"
      />,
    );
    fireEvent.click(
      await screen.findByRole("button", {
        name: "Accept reservation for Drill",
      }),
    );
    expect(await screen.findByText("Status: Accepted")).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /accept|refuse/i })).toBeNull();
  });

  it("presents a server conflict clearly and keeps the refreshed status", async () => {
    rpc.mockImplementation((name: string) => {
      if (name === "list_booking_requests") {
        return Promise.resolve({
          data: [
            {
              id: "booking-a",
              item_id: "item-a",
              item_name: "Drill",
              start_date: "2026-08-15",
              end_date: "2026-08-16",
              status: "requested",
              is_borrower: false,
              is_item_owner: false,
              can_decide: true,
              borrower_label: "Community member",
            },
          ],
          error: null,
        });
      }
      if (name === "decide_booking") {
        return Promise.resolve({
          data: null,
          error: new Error(
            "These dates conflict with another accepted booking",
          ),
        });
      }
      return Promise.resolve({ data: [], error: null });
    });
    render(
      <ItemSection
        communities={[
          { id: "community-a", name: "Riverside", join_code: "join-code" },
        ]}
        currentUserId="admin-a"
      />,
    );
    fireEvent.click(
      await screen.findByRole("button", {
        name: "Accept reservation for Drill",
      }),
    );
    expect(
      await screen.findByText(/conflict with another accepted reservation/i),
    ).toBeInTheDocument();
    expect(screen.getByText("Status: Requested")).toBeInTheDocument();
  });

  it("advances accepted handover and checked-out return from authoritative refreshes", async () => {
    let status: "accepted" | "checked_out" | "returned" = "accepted";
    rpc.mockImplementation((name: string) => {
      if (name === "list_booking_requests")
        return Promise.resolve({
          data: [
            {
              id: "booking-a",
              item_id: "item-a",
              item_name: "Drill",
              start_date: "2026-08-15",
              end_date: "2026-08-16",
              status,
              is_borrower: true,
              is_item_owner: false,
              can_decide: false,
              borrower_label: "You",
            },
          ],
          error: null,
        });
      if (name === "record_handover") status = "checked_out";
      if (name === "record_return") status = "returned";
      return Promise.resolve({ data: [], error: null });
    });
    render(
      <ItemSection
        communities={[
          { id: "community-a", name: "Riverside", join_code: "join" },
        ]}
        currentUserId="borrower-a"
      />,
    );
    fireEvent.click(
      await screen.findByRole("button", { name: "Mark Drill as handed over" }),
    );
    expect(await screen.findByText("Status: Checked out")).toBeInTheDocument();
    expect(rpc).toHaveBeenCalledWith("record_handover", {
      target_booking_id: "booking-a",
    });
    fireEvent.click(
      screen.getByRole("button", { name: "Mark Drill as returned" }),
    );
    expect(
      await screen.findByRole("heading", {
        name: "Transaction history",
      }),
    ).toBeInTheDocument();
    expect(await screen.findByText("Status: Returned")).toBeInTheDocument();
    expect(
      screen.queryByRole("button", { name: /handed over|returned/ }),
    ).toBeNull();
  });

  it("shows cancellation only for eligible booking participants and states", async () => {
    rpc.mockImplementation((name: string) =>
      Promise.resolve({
        data:
          name === "list_booking_requests"
            ? [
                {
                  id: "borrower-requested",
                  item_id: "item-a",
                  item_name: "Requested drill",
                  start_date: "2026-09-01",
                  end_date: "2026-09-01",
                  status: "requested",
                  is_borrower: true,
                  is_item_owner: false,
                  can_decide: false,
                  borrower_label: "You",
                },
                {
                  id: "borrower-accepted",
                  item_id: "item-b",
                  item_name: "Accepted sander",
                  start_date: "2026-09-02",
                  end_date: "2026-09-02",
                  status: "accepted",
                  is_borrower: true,
                  is_item_owner: false,
                  can_decide: false,
                  borrower_label: "You",
                },
                {
                  id: "owner-requested",
                  item_id: "item-c",
                  item_name: "Owner saw",
                  start_date: "2026-09-03",
                  end_date: "2026-09-03",
                  status: "requested",
                  is_borrower: false,
                  is_item_owner: true,
                  can_decide: true,
                  borrower_label: "Community member",
                },
                {
                  id: "owner-accepted",
                  item_id: "item-d",
                  item_name: "Owner plane",
                  start_date: "2026-09-04",
                  end_date: "2026-09-04",
                  status: "accepted",
                  is_borrower: false,
                  is_item_owner: true,
                  can_decide: false,
                  borrower_label: "Community member",
                },
                {
                  id: "admin-requested",
                  item_id: "item-e",
                  item_name: "Admin router",
                  start_date: "2026-09-05",
                  end_date: "2026-09-05",
                  status: "requested",
                  is_borrower: false,
                  is_item_owner: false,
                  can_decide: true,
                  borrower_label: "Community member",
                },
                {
                  id: "checked-out",
                  item_id: "item-f",
                  item_name: "Checked out level",
                  start_date: "2026-09-06",
                  end_date: "2026-09-06",
                  status: "checked_out",
                  is_borrower: true,
                  is_item_owner: false,
                  can_decide: false,
                  borrower_label: "You",
                },
                {
                  id: "cancelled",
                  item_id: "item-g",
                  item_name: "Cancelled clamp",
                  start_date: "2026-09-07",
                  end_date: "2026-09-07",
                  status: "cancelled",
                  is_borrower: true,
                  is_item_owner: false,
                  can_decide: false,
                  borrower_label: "You",
                },
              ]
            : [],
        error: null,
      }),
    );
    render(<ItemSection communities={[community]} currentUserId="member-a" />);

    expect(
      await screen.findByRole("button", {
        name: "Cancel reservation for Requested drill",
      }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("button", {
        name: "Cancel reservation for Accepted sander",
      }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("button", {
        name: "Cancel reservation for Owner plane",
      }),
    ).toBeInTheDocument();
    expect(
      screen.queryByRole("button", {
        name: /Cancel reservation for Owner saw/,
      }),
    ).toBeNull();
    expect(
      screen.queryByRole("button", {
        name: /Cancel reservation for Admin router/,
      }),
    ).toBeNull();
    expect(
      screen.queryByRole("button", {
        name: /Cancel reservation for Checked out level/,
      }),
    ).toBeNull();
    expect(screen.getByText("Status: Cancelled")).toBeInTheDocument();
    expect(
      screen.getByRole("heading", { name: "Transaction history" }),
    ).toBeInTheDocument();
  });

  it("uses only the cancellation RPC once, refreshes, and announces success", async () => {
    let status: "requested" | "cancelled" = "requested";
    let finish: (() => void) | undefined;
    rpc.mockImplementation((name: string, parameters?: unknown) => {
      if (name === "list_booking_requests")
        return Promise.resolve({
          data: [
            {
              id: "booking-a",
              item_id: "item-a",
              item_name: "Drill",
              start_date: "2026-09-01",
              end_date: "2026-09-01",
              status,
              is_borrower: true,
              is_item_owner: false,
              can_decide: false,
              borrower_label: "You",
            },
          ],
          error: null,
        });
      if (name === "cancel_booking") {
        expect(parameters).toEqual({ target_booking_id: "booking-a" });
        return new Promise((resolve) => {
          finish = () => {
            status = "cancelled";
            resolve({ data: [], error: null });
          };
        });
      }
      return Promise.resolve({ data: [], error: null });
    });
    render(
      <ItemSection communities={[community]} currentUserId="borrower-a" />,
    );
    const cancel = await screen.findByRole("button", {
      name: "Cancel reservation for Drill",
    });
    fireEvent.click(cancel);
    fireEvent.click(cancel);
    expect(cancel).toBeDisabled();
    expect(
      rpc.mock.calls.filter(([name]) => name === "cancel_booking"),
    ).toHaveLength(1);
    finish?.();
    expect(await screen.findByText("Status: Cancelled")).toBeInTheDocument();
    expect(
      screen.getByText(
        "Reservation cancelled. It is preserved in your history.",
      ),
    ).toHaveAttribute("role", "status");
  });

  it("announces a stale cancellation rejection and refreshes authoritative state", async () => {
    let calls = 0;
    rpc.mockImplementation((name: string) => {
      if (name === "list_booking_requests") {
        calls += 1;
        return Promise.resolve({
          data: [
            {
              id: "booking-a",
              item_id: "item-a",
              item_name: "Drill",
              start_date: "2026-09-01",
              end_date: "2026-09-01",
              status: calls === 1 ? "accepted" : "checked_out",
              is_borrower: true,
              is_item_owner: false,
              can_decide: false,
              borrower_label: "You",
            },
          ],
          error: null,
        });
      }
      if (name === "cancel_booking")
        return Promise.resolve({
          data: null,
          error: new Error("Booking cannot be cancelled after handover"),
        });
      return Promise.resolve({ data: [], error: null });
    });
    render(
      <ItemSection communities={[community]} currentUserId="borrower-a" />,
    );
    fireEvent.click(
      await screen.findByRole("button", {
        name: "Cancel reservation for Drill",
      }),
    );
    expect(await screen.findByRole("alert")).toHaveTextContent(
      "cannot be cancelled after handover",
    );
    expect(screen.getByText("Status: Checked out")).toBeInTheDocument();
    expect(calls).toBeGreaterThan(1);
  });

  it("offers phase-specific labelled condition evidence uploads", async () => {
    rpc.mockImplementation((name: string) =>
      Promise.resolve({
        data:
          name === "list_booking_requests"
            ? [
                {
                  id: "booking-a",
                  item_id: "item-a",
                  item_name: "Drill",
                  start_date: "2026-08-15",
                  end_date: "2026-08-16",
                  status: "accepted",
                  is_borrower: true,
                  is_item_owner: false,
                  can_decide: false,
                  borrower_label: "You",
                },
              ]
            : [],
        error: null,
      }),
    );
    render(
      <ItemSection
        communities={[
          { id: "community-a", name: "Riverside", join_code: "join" },
        ]}
        currentUserId="borrower-a"
      />,
    );
    const input = await screen.findByLabelText(/Before condition photo/);
    expect(input).toHaveAttribute("accept", "image/jpeg,image/png,image/webp");
    expect(
      screen.getByRole("button", { name: "Add before condition photo" }),
    ).toBeInTheDocument();
    expect(screen.queryByLabelText(/After condition photo/)).toBeNull();
  });
});
