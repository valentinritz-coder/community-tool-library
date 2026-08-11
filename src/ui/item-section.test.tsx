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
            "Available from 2026-08-12 through 2026-08-15; Unavailable on 2026-08-18",
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
        "Availability: Available from 2026-08-12 through 2026-08-15; Unavailable on 2026-08-18",
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
    expect(screen.getByLabelText("Range type")).toHaveValue("available");
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
        kind: "available",
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
          availability_summary: "Not set by the owner.",
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
      await screen.findByText("Availability: Not set by the owner."),
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
});
