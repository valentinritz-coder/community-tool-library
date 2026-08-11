import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { ItemSection } from "./item-section";

const query = {
  select: vi.fn(() => query),
  order: vi.fn().mockResolvedValue({ data: [], error: null }),
  insert: vi.fn().mockResolvedValue({ error: null }),
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
      from: vi.fn(() => ({ createSignedUrl })),
    },
  }),
}));

describe("ItemSection", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    query.order.mockResolvedValue({ data: [], error: null });
    rpc.mockResolvedValue({ data: [], error: null });
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
    expect(screen.getByLabelText("Safe category")).toHaveTextContent(
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
    expect(
      await screen.findByText(
        "The end date must be on or after the start date.",
      ),
    ).toBeInTheDocument();
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
});
