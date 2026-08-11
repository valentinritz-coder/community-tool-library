import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { ItemSection } from "./item-section";

const query = {
  select: vi.fn(() => query),
  order: vi.fn().mockResolvedValue({ data: [], error: null }),
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
    expect(screen.getByText("Availability: not set yet")).toBeInTheDocument();
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
