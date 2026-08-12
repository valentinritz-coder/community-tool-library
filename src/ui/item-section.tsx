"use client";

/* eslint-disable @next/next/no-img-element -- private, short-lived signed Storage URLs cannot be statically optimized */

import type { FormEvent } from "react";
import { useCallback, useEffect, useRef, useState } from "react";

import type { Community } from "../domain/community";
import {
  bookingStatusLabel,
  validateBookingDates,
  type BookingContact,
  type BookingRequest,
  type ConditionPhase,
  type ConditionReport,
} from "../domain/booking";
import {
  availabilityLabel,
  validateAvailabilityDates,
  type Availability,
} from "../domain/availability";
import {
  inventoryItems,
  itemCategoryLabel,
  itemCategories,
  photoExtension,
  priceToCents,
  type InventoryItem,
  type Item,
} from "../domain/item";
import { getSupabaseBrowserClient } from "../infrastructure/supabase-browser";
import {
  moderationReasonLabel,
  moderationReasons,
  type ModerationReport,
} from "../domain/moderation";

interface ItemSectionProps {
  communities: Community[];
  currentUserId: string;
  adminCommunityIds?: string[];
}

const noAdminCommunities: string[] = [];

function messageFor(error: unknown): string {
  return error instanceof Error
    ? error.message
    : typeof error === "object" && error !== null && "message" in error
      ? String(error.message)
      : "The action could not be completed. Try again.";
}

export function ItemSection({
  communities,
  currentUserId,
  adminCommunityIds = noAdminCommunities,
}: ItemSectionProps) {
  const [items, setItems] = useState<Item[]>([]);
  const [inventory, setInventory] = useState<InventoryItem[]>([]);
  const [availabilities, setAvailabilities] = useState<Availability[]>([]);
  const [bookings, setBookings] = useState<BookingRequest[]>([]);
  const [bookingContacts, setBookingContacts] = useState<BookingContact[]>([]);
  const [conditionReports, setConditionReports] = useState<ConditionReport[]>(
    [],
  );
  const [conditionPhotoUrls, setConditionPhotoUrls] = useState<
    Record<string, string>
  >({});
  const [photoUrls, setPhotoUrls] = useState<Record<string, string>>({});
  const [message, setMessage] = useState("");
  const [messageIsError, setMessageIsError] = useState(false);
  const [invalidFields, setInvalidFields] = useState<string[]>([]);
  const [paid, setPaid] = useState(false);
  const [search, setSearch] = useState("");
  const [inventoryCommunityId, setInventoryCommunityId] = useState("");
  const [loading, setLoading] = useState(true);
  const [pendingActions, setPendingActions] = useState<string[]>([]);
  const [moderationReports, setModerationReports] = useState<
    ModerationReport[]
  >([]);
  const pendingActionsRef = useRef(new Set<string>());

  function announce(
    nextMessage: string,
    options: { error?: boolean; fields?: string[] } = {},
  ) {
    setMessage(nextMessage);
    setMessageIsError(options.error ?? false);
    setInvalidFields(options.fields ?? []);
  }

  function fieldErrorProps(id: string) {
    return invalidFields.includes(id)
      ? { "aria-invalid": true as const, "aria-errormessage": "item-message" }
      : {};
  }

  function beginAction(action: string): boolean {
    if (pendingActionsRef.current.has(action)) return false;
    pendingActionsRef.current.add(action);
    setPendingActions([...pendingActionsRef.current]);
    announce("Working…");
    return true;
  }

  function endAction(action: string) {
    pendingActionsRef.current.delete(action);
    setPendingActions([...pendingActionsRef.current]);
  }

  function isPending(action: string): boolean {
    return pendingActions.includes(action);
  }

  const refresh = useCallback(async () => {
    const supabase = getSupabaseBrowserClient();
    const communityId = inventoryCommunityId || communities.at(0)?.id || "";
    const [
      ownedResult,
      inventoryResult,
      availabilityResult,
      bookingResult,
      contactResult,
      conditionResult,
    ] = await Promise.all([
      supabase
        .from("items")
        .select(
          "id,community_id,owner_id,name,category,description,photo_path,is_free,price_per_day_cents,archived,photo_uploaded",
        )
        .order("created_at", { ascending: false }),
      communityId
        ? supabase.rpc("browse_community_inventory", {
            target_community_id: communityId,
          })
        : Promise.resolve({ data: [], error: null }),
      supabase
        .from("availabilities")
        .select("id,item_id,start_date,end_date")
        .order("start_date", { ascending: true }),
      supabase.rpc("list_booking_requests"),
      supabase.rpc("list_accepted_booking_contacts"),
      supabase
        .from("condition_reports")
        .select("id,booking_id,phase,photo_path,created_at")
        .order("created_at", { ascending: true }),
    ]);
    if (ownedResult.error) throw ownedResult.error;
    if (inventoryResult.error) throw inventoryResult.error;
    if (availabilityResult.error) throw availabilityResult.error;
    if (bookingResult.error) throw bookingResult.error;
    if (contactResult.error) throw contactResult.error;
    if (conditionResult.error) throw conditionResult.error;
    const nextItems = ownedResult.data as Item[];
    const nextInventory = inventoryResult.data as InventoryItem[];
    const urls: Record<string, string> = {};
    await Promise.all(
      [...nextInventory, ...nextItems].map(async (item) => {
        const signed = await supabase.storage
          .from("item-photos")
          .createSignedUrl(item.photo_path, 300);
        if (!signed.error) urls[item.id] = signed.data.signedUrl;
      }),
    );
    setItems(nextItems);
    setInventory(nextInventory);
    setAvailabilities(availabilityResult.data as Availability[]);
    setBookings(bookingResult.data as BookingRequest[]);
    setBookingContacts(contactResult.data as BookingContact[]);
    const reports = conditionResult.data as ConditionReport[];
    const conditionUrls: Record<string, string> = {};
    await Promise.all(
      reports.map(async (report) => {
        const signed = await supabase.storage
          .from("condition-photos")
          .createSignedUrl(report.photo_path, 300);
        if (!signed.error) conditionUrls[report.id] = signed.data.signedUrl;
      }),
    );
    setConditionReports(reports);
    setConditionPhotoUrls(conditionUrls);
    setPhotoUrls(urls);
    setLoading(false);
    if (communityId && adminCommunityIds.includes(communityId)) {
      const reports = await supabase.rpc("list_moderation_reports", {
        target_community_id: communityId,
      });
      if (reports.error) throw reports.error;
      setModerationReports(reports.data as ModerationReport[]);
    } else setModerationReports([]);
  }, [adminCommunityIds, communities, inventoryCommunityId]);

  useEffect(() => {
    const loadItems = window.setTimeout(() => {
      void refresh().catch((error: unknown) => {
        setLoading(false);
        announce(messageFor(error), { error: true });
      });
    }, 0);
    return () => window.clearTimeout(loadItems);
  }, [refresh]);

  const selectedCommunityId =
    inventoryCommunityId || communities.at(0)?.id || "";
  const communityInventory = inventoryItems(inventory, search);
  const publishedInventory = inventoryItems(inventory, "");
  const ownItems = items.filter((item) => item.owner_id === currentUserId);

  async function createItem(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    announce("");
    const form = new FormData(event.currentTarget);
    const price = paid ? priceToCents(String(form.get("price") ?? "")) : null;
    if (paid && price === null) {
      announce("Enter a daily price between 0.01 and 1000.00.", {
        error: true,
        fields: ["item-price"],
      });
      return;
    }
    const photo = form.get("photo");
    if (!(photo instanceof File) || photo.size === 0) {
      announce("Choose one photo for the item.", {
        error: true,
        fields: ["item-photo"],
      });
      return;
    }
    const extension = photoExtension(photo);
    if (!extension) {
      announce("Use a JPEG, PNG, or WebP photo.", {
        error: true,
        fields: ["item-photo"],
      });
      return;
    }
    if (photo.size > 5 * 1024 * 1024) {
      announce("The photo must be 5 MB or smaller.", {
        error: true,
        fields: ["item-photo"],
      });
      return;
    }
    if (!beginAction("create-item")) return;
    try {
      const supabase = getSupabaseBrowserClient();
      const created = await supabase.rpc("create_item", {
        target_community_id: String(form.get("community")),
        item_name: String(form.get("name")),
        item_category: String(form.get("category")),
        item_description: String(form.get("description")),
        item_is_free: !paid,
        item_price_per_day_cents: price,
        photo_extension: extension,
      });
      if (created.error) throw created.error;
      const item = created.data as Item;
      const uploaded = await supabase.storage
        .from("item-photos")
        .upload(item.photo_path, photo, {
          contentType: photo.type,
          upsert: false,
        });
      if (uploaded.error) throw uploaded.error;
      const published = await supabase.rpc("publish_item", {
        target_item_id: item.id,
      });
      if (published.error) throw published.error;
      event.currentTarget.reset();
      setPaid(false);
      await refresh();
      setMessage("Item listed for your community.");
    } catch (error) {
      announce(messageFor(error), { error: true });
    } finally {
      endAction("create-item");
    }
  }

  async function updateItem(event: FormEvent<HTMLFormElement>, item: Item) {
    event.preventDefault();
    announce("");
    const form = new FormData(event.currentTarget);
    const free = form.get("terms") === "free";
    const price = free ? null : priceToCents(String(form.get("price") ?? ""));
    if (!free && price === null) {
      announce("Enter a daily price between 0.01 and 1000.00.", {
        error: true,
        fields: [`price-${item.id}`],
      });
      return;
    }
    const replacement = form.get("photo");
    if (replacement instanceof File && replacement.size > 0) {
      const extension = photoExtension(replacement);
      if (
        !extension ||
        !item.photo_path.endsWith(`.${extension}`) ||
        replacement.size > 5 * 1024 * 1024
      ) {
        announce(
          "The replacement must use the same JPEG, PNG, or WebP format and be 5 MB or smaller.",
          { error: true, fields: [`photo-${item.id}`] },
        );
        return;
      }
    }
    const action = `update-item-${item.id}`;
    if (!beginAction(action)) return;
    try {
      const result = await getSupabaseBrowserClient()
        .from("items")
        .update({
          name: String(form.get("name")),
          category: String(form.get("category")),
          description: String(form.get("description")),
          is_free: free,
          price_per_day_cents: price,
        })
        .eq("id", item.id);
      if (result.error) announce(messageFor(result.error), { error: true });
      else {
        if (replacement instanceof File && replacement.size > 0) {
          const uploaded = await getSupabaseBrowserClient()
            .storage.from("item-photos")
            .upload(item.photo_path, replacement, {
              contentType: replacement.type,
              upsert: true,
            });
          if (uploaded.error) {
            announce(messageFor(uploaded.error), { error: true });
            return;
          }
          if (!item.photo_uploaded) {
            const published = await getSupabaseBrowserClient().rpc(
              "publish_item",
              { target_item_id: item.id },
            );
            if (published.error) {
              announce(messageFor(published.error), { error: true });
              return;
            }
          }
        }
        await refresh();
        setMessage("Item changes saved.");
      }
    } finally {
      endAction(action);
    }
  }

  async function archive(itemId: string) {
    const action = `archive-item-${itemId}`;
    if (!beginAction(action)) return;
    try {
      const result = await getSupabaseBrowserClient()
        .from("items")
        .update({ archived: true })
        .eq("id", itemId);
      if (result.error) announce(messageFor(result.error), { error: true });
      else {
        await refresh();
        setMessage("Item archived.");
      }
    } finally {
      endAction(action);
    }
  }

  async function addAvailability(
    event: FormEvent<HTMLFormElement>,
    itemId: string,
  ) {
    event.preventDefault();
    const formElement = event.currentTarget;
    announce("");
    const form = new FormData(formElement);
    const startDate = String(form.get("start_date") ?? "");
    const endDate = String(form.get("end_date") ?? "");
    const dateError = validateAvailabilityDates(startDate, endDate);
    if (dateError) {
      announce(dateError, {
        error: true,
        fields: [`availability-start-${itemId}`, `availability-end-${itemId}`],
      });
      return;
    }
    const action = `availability-add-${itemId}`;
    if (!beginAction(action)) return;
    try {
      const result = await getSupabaseBrowserClient()
        .from("availabilities")
        .insert({
          item_id: itemId,
          start_date: startDate,
          end_date: endDate,
        });
      if (result.error) {
        setMessage(
          result.error.message.includes("availability_ranges_do_not_overlap")
            ? "This range overlaps an existing availability range."
            : messageFor(result.error),
        );
        setMessageIsError(true);
        return;
      }
      formElement.reset();
      await refresh();
      setMessage("Availability range added.");
    } finally {
      endAction(action);
    }
  }

  async function removeAvailability(availabilityId: string) {
    announce("");
    const action = `availability-remove-${availabilityId}`;
    if (!beginAction(action)) return;
    try {
      const result = await getSupabaseBrowserClient()
        .from("availabilities")
        .delete()
        .eq("id", availabilityId);
      if (result.error) announce(messageFor(result.error), { error: true });
      else {
        await refresh();
        setMessage("Availability range removed.");
      }
    } finally {
      endAction(action);
    }
  }

  async function requestBooking(
    event: FormEvent<HTMLFormElement>,
    itemId: string,
  ) {
    event.preventDefault();
    const formElement = event.currentTarget;
    announce("");
    const form = new FormData(formElement);
    const startDate = String(form.get("start_date") ?? "");
    const endDate = String(form.get("end_date") ?? "");
    const dateError = validateBookingDates(startDate, endDate);
    if (dateError) {
      announce(dateError, {
        error: true,
        fields: [`booking-start-${itemId}`, `booking-end-${itemId}`],
      });
      return;
    }
    const action = `booking-request-${itemId}`;
    if (!beginAction(action)) return;
    try {
      const result = await getSupabaseBrowserClient().rpc("request_booking", {
        target_item_id: itemId,
        requested_start_date: startDate,
        requested_end_date: endDate,
      });
      if (result.error) {
        setMessage(
          result.error.message.includes("not fully available")
            ? "Those dates are not fully available. Choose dates covered by the owner's availability."
            : messageFor(result.error),
        );
        setMessageIsError(true);
        return;
      }
      formElement.reset();
      await refresh();
      setMessage("Reservation request created with Requested status.");
    } finally {
      endAction(action);
    }
  }

  async function decideBooking(
    booking: BookingRequest,
    decision: "accepted" | "refused",
  ) {
    announce("");
    const action = `booking-decision-${booking.id}`;
    if (!beginAction(action)) return;
    try {
      const result = await getSupabaseBrowserClient().rpc("decide_booking", {
        target_booking_id: booking.id,
        decision,
      });
      if (result.error) {
        const serverMessage = result.error.message;
        if (serverMessage.includes("already been decided")) {
          setMessage(
            "This reservation request has already been decided. Refreshing its status.",
          );
        } else if (serverMessage.includes("conflict")) {
          setMessage(
            "These dates conflict with another accepted reservation. The request remains Requested.",
          );
        } else if (serverMessage.includes("no longer fully available")) {
          setMessage(
            "The item is no longer available for all of these dates. The request remains Requested.",
          );
        } else if (serverMessage.includes("no longer valid")) {
          setMessage(
            "This reservation request is no longer valid and could not be accepted.",
          );
        } else if (serverMessage.includes("Only the item owner")) {
          setMessage(
            "You are not authorized to decide this reservation request.",
          );
        } else {
          announce(messageFor(result.error), { error: true });
        }
        setMessageIsError(true);
        await refresh().catch(() => undefined);
        return;
      }
      await refresh();
      setMessage(
        decision === "accepted"
          ? "Reservation accepted. The participants can now see each other's contact email."
          : "Reservation refused.",
      );
    } finally {
      endAction(action);
    }
  }

  async function advanceBooking(booking: BookingRequest) {
    announce("");
    const handover = booking.status === "accepted";
    const action = `booking-advance-${booking.id}`;
    if (!beginAction(action)) return;
    try {
      const result = await getSupabaseBrowserClient().rpc(
        handover ? "record_handover" : "record_return",
        { target_booking_id: booking.id },
      );
      if (result.error) {
        setMessage(
          result.error.message.includes("required state")
            ? "This transaction was already updated. Refreshing its status."
            : messageFor(result.error),
        );
        setMessageIsError(true);
        await refresh().catch(() => undefined);
        return;
      }
      await refresh();
      setMessage(
        handover
          ? "Handover recorded. Status is now Checked out."
          : "Return recorded. This transaction is now in your history.",
      );
    } finally {
      endAction(action);
    }
  }

  async function uploadCondition(
    event: FormEvent<HTMLFormElement>,
    booking: BookingRequest,
    phase: ConditionPhase,
  ) {
    event.preventDefault();
    const formElement = event.currentTarget;
    const photo = new FormData(formElement).get("condition_photo");
    if (!(photo instanceof File) || photo.size === 0) {
      announce("Choose a condition photo.", {
        error: true,
        fields: [`condition-${phase}-${booking.id}`],
      });
      return;
    }
    const extension = photoExtension(photo);
    if (!extension) {
      announce("Use a JPEG, PNG, or WebP photo.", {
        error: true,
        fields: [`condition-${phase}-${booking.id}`],
      });
      return;
    }
    if (photo.size > 5 * 1024 * 1024) {
      announce("The photo must be 5 MB or smaller.", {
        error: true,
        fields: [`condition-${phase}-${booking.id}`],
      });
      return;
    }
    const action = `condition-${phase}-${booking.id}`;
    if (!beginAction(action)) return;
    try {
      const supabase = getSupabaseBrowserClient();
      const reserved = await supabase.rpc("create_condition_report", {
        target_booking_id: booking.id,
        report_phase: phase,
        photo_extension: extension,
      });
      if (reserved.error) {
        announce(messageFor(reserved.error), {
          error: true,
          fields: [`condition-${phase}-${booking.id}`],
        });
        await refresh().catch(() => undefined);
        return;
      }
      const report = (reserved.data as ConditionReport[])[0];
      if (!report) {
        announce("The condition photo could not be prepared. Try again.", {
          error: true,
          fields: [`condition-${phase}-${booking.id}`],
        });
        return;
      }
      const uploaded = await supabase.storage
        .from("condition-photos")
        .upload(report.photo_path, photo, {
          contentType: photo.type,
          upsert: false,
        });
      if (uploaded.error) {
        announce("The condition photo could not be uploaded. Try again.", {
          error: true,
          fields: [`condition-${phase}-${booking.id}`],
        });
        return;
      }
      formElement.reset();
      await refresh();
      setMessage(
        `${phase === "before" ? "Before" : "After"} condition photo added.`,
      );
    } finally {
      endAction(action);
    }
  }

  function workflow(booking: BookingRequest) {
    const phase: ConditionPhase | null =
      booking.status === "accepted"
        ? "before"
        : booking.status === "checked_out"
          ? "after"
          : null;
    const reports = conditionReports.filter(
      (report) => report.booking_id === booking.id,
    );
    return (
      <>
        {reports.length > 0 && (
          <div
            className="condition-evidence"
            aria-label={`Condition evidence for ${booking.item_name}`}
          >
            {reports.map(
              (report) =>
                conditionPhotoUrls[report.id] && (
                  <figure key={report.id}>
                    <img
                      src={conditionPhotoUrls[report.id]}
                      alt={`${report.phase === "before" ? "Before" : "After"} condition evidence for ${booking.item_name}`}
                    />
                    <figcaption>
                      {report.phase === "before" ? "Before" : "After"} condition
                    </figcaption>
                  </figure>
                ),
            )}
          </div>
        )}
        {phase && (
          <form
            aria-label={`Add ${phase} condition for ${booking.item_name}`}
            aria-busy={isPending(`condition-${phase}-${booking.id}`)}
            onSubmit={(event) => void uploadCondition(event, booking, phase)}
          >
            <label htmlFor={`condition-${phase}-${booking.id}`}>
              {phase === "before" ? "Before" : "After"} condition photo
              (optional; JPEG, PNG, or WebP; maximum 5 MB)
            </label>
            <input
              id={`condition-${phase}-${booking.id}`}
              name="condition_photo"
              type="file"
              accept="image/jpeg,image/png,image/webp"
              {...fieldErrorProps(`condition-${phase}-${booking.id}`)}
            />
            <button
              type="submit"
              disabled={isPending(`condition-${phase}-${booking.id}`)}
            >
              Add {phase} condition photo
            </button>
          </form>
        )}
        {booking.status === "accepted" && (
          <button
            type="button"
            aria-label={`Mark ${booking.item_name} as handed over`}
            disabled={isPending(`booking-advance-${booking.id}`)}
            onClick={() => void advanceBooking(booking)}
          >
            Mark as handed over
          </button>
        )}
        {booking.status === "checked_out" && (
          <button
            type="button"
            aria-label={`Mark ${booking.item_name} as returned`}
            disabled={isPending(`booking-advance-${booking.id}`)}
            onClick={() => void advanceBooking(booking)}
          >
            Mark as returned
          </button>
        )}
      </>
    );
  }

  function contactFor(bookingId: string): BookingContact | undefined {
    return bookingContacts.find((contact) => contact.booking_id === bookingId);
  }

  async function submitReport(
    event: FormEvent<HTMLFormElement>,
    target: "item" | "counterparty",
    id: string,
  ) {
    event.preventDefault();
    const formElement = event.currentTarget;
    const form = new FormData(formElement);
    const action = `report-${target}-${id}`;
    if (!beginAction(action)) return;
    try {
      const result = await getSupabaseBrowserClient().rpc(
        target === "item" ? "submit_item_report" : "submit_counterparty_report",
        {
          [target === "item" ? "target_item_id" : "target_booking_id"]: id,
          report_reason: String(form.get("reason")),
          report_note: String(form.get("note") ?? "") || null,
        },
      );
      if (result.error) throw result.error;
      formElement.reset();
      announce("Report submitted.");
    } catch (error) {
      announce(messageFor(error), { error: true });
    } finally {
      endAction(action);
    }
  }

  async function moderate(report: ModerationReport, hide: boolean) {
    const action = `moderate-${report.id}`;
    if (!beginAction(action)) return;
    try {
      const result = await getSupabaseBrowserClient().rpc(
        hide ? "hide_reported_item" : "handle_moderation_report",
        { target_report_id: report.id },
      );
      if (result.error) throw result.error;
      await refresh();
      announce(
        hide ? "Item hidden and report handled." : "Report marked as handled.",
      );
    } catch (error) {
      announce(messageFor(error), { error: true });
    } finally {
      endAction(action);
    }
  }

  function reportForm(
    target: "item" | "counterparty",
    id: string,
    label: string,
  ) {
    const action = `report-${target}-${id}`;
    return (
      <details>
        <summary>
          {target === "item"
            ? "Report item"
            : "Report transaction counterparty"}
        </summary>
        <form
          aria-label={`Report ${label}`}
          aria-busy={isPending(action)}
          onSubmit={(event) => void submitReport(event, target, id)}
        >
          <label htmlFor={`reason-${target}-${id}`}>Reason</label>
          <select id={`reason-${target}-${id}`} name="reason" required>
            {moderationReasons.map((reason) => (
              <option key={reason.value} value={reason.value}>
                {reason.label}
              </option>
            ))}
          </select>
          <label htmlFor={`note-${target}-${id}`}>
            Additional note (optional, maximum 500 characters)
          </label>
          <textarea id={`note-${target}-${id}`} name="note" maxLength={500} />
          <button type="submit" disabled={isPending(action)}>
            Submit report
          </button>
        </form>
      </details>
    );
  }

  return (
    <section className="card wide" aria-labelledby="items-title">
      <h2 id="items-title">Community inventory</h2>
      <p
        id="item-message"
        className="notice"
        role={messageIsError ? "alert" : "status"}
        aria-live={messageIsError ? "assertive" : "polite"}
      >
        {message}
      </p>
      {communities.length === 0 ? (
        <p>Join a community as an active member to browse its inventory.</p>
      ) : (
        <>
          <div className="inventory-controls">
            <label htmlFor="inventory-community">Community</label>
            <select
              id="inventory-community"
              value={selectedCommunityId}
              onChange={(event) => setInventoryCommunityId(event.target.value)}
            >
              {communities.map((community) => (
                <option key={community.id} value={community.id}>
                  {community.name}
                </option>
              ))}
            </select>
            <label htmlFor="inventory-search">Search inventory</label>
            <input
              id="inventory-search"
              type="search"
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder="Item name or category"
            />
          </div>
          <p className="visually-hidden" role="status" aria-live="polite">
            {!loading &&
              `${communityInventory.length} ${communityInventory.length === 1 ? "item" : "items"} shown.`}
          </p>
          {loading ? (
            <p role="status">Loading community inventory…</p>
          ) : communityInventory.length > 0 ? (
            <div className="item-list">
              {communityInventory.map((item) => (
                <article key={item.id} className="item-card">
                  <h3>{item.name}</h3>
                  {photoUrls[item.id] ? (
                    <img
                      src={photoUrls[item.id]}
                      alt={`Photo of ${item.name}`}
                    />
                  ) : (
                    <p>Photo temporarily unavailable.</p>
                  )}
                  <p className="item-category">
                    {itemCategoryLabel(item.category)}
                  </p>
                  <p>{item.description}</p>
                  <p>
                    <strong>
                      {item.is_free
                        ? "Free loan"
                        : `${(item.price_per_day_cents! / 100).toFixed(2)} per day`}
                    </strong>
                  </p>
                  <p>Owner: {item.is_owned ? "You" : "Community member"}</p>
                  <p>Availability: {item.availability_summary}</p>
                  {reportForm("item", item.id, item.name)}
                  {!item.is_owned && (
                    <form
                      aria-label={`Request ${item.name}`}
                      aria-busy={isPending(`booking-request-${item.id}`)}
                      onSubmit={(event) => void requestBooking(event, item.id)}
                    >
                      <label htmlFor={`booking-start-${item.id}`}>
                        Start date
                      </label>
                      <input
                        id={`booking-start-${item.id}`}
                        name="start_date"
                        type="date"
                        required
                        {...fieldErrorProps(`booking-start-${item.id}`)}
                      />
                      <label htmlFor={`booking-end-${item.id}`}>End date</label>
                      <input
                        id={`booking-end-${item.id}`}
                        name="end_date"
                        type="date"
                        required
                        {...fieldErrorProps(`booking-end-${item.id}`)}
                      />
                      <button
                        type="submit"
                        disabled={isPending(`booking-request-${item.id}`)}
                      >
                        Request reservation
                      </button>
                    </form>
                  )}
                </article>
              ))}
            </div>
          ) : publishedInventory.length === 0 ? (
            <p className="empty-state">
              This community does not have any listed items yet.
            </p>
          ) : (
            <p className="empty-state" role="status">
              No items match your search. Try an item name or category.
            </p>
          )}
        </>
      )}
      <section
        className="booking-requests"
        aria-labelledby="your-bookings-title"
      >
        <h3 id="your-bookings-title">Your reservation requests</h3>
        {bookings.filter(
          (booking) => booking.is_borrower && booking.status !== "returned",
        ).length === 0 ? (
          <p>You have not requested a reservation yet.</p>
        ) : (
          <ul>
            {bookings
              .filter(
                (booking) =>
                  booking.is_borrower && booking.status !== "returned",
              )
              .map((booking) => (
                <li key={`borrower-${booking.id}`}>
                  <strong>{booking.item_name}</strong>
                  <span>
                    {booking.start_date} through {booking.end_date}
                  </span>
                  <span>Status: {bookingStatusLabel[booking.status]}</span>
                  {contactFor(booking.id) && (
                    <span>
                      Contact email:{" "}
                      {contactFor(booking.id)!.counterparty_email}
                    </span>
                  )}
                  {workflow(booking)}
                  {reportForm(
                    "counterparty",
                    booking.id,
                    `counterparty for ${booking.item_name}`,
                  )}
                </li>
              ))}
          </ul>
        )}
      </section>
      <section
        className="booking-requests"
        aria-labelledby="owner-bookings-title"
      >
        <h3 id="owner-bookings-title">Reservation decisions</h3>
        {bookings.filter(
          (booking) =>
            (booking.is_item_owner || booking.can_decide) &&
            booking.status !== "returned",
        ).length === 0 ? (
          <p>No reservation requests for you to decide.</p>
        ) : (
          <ul>
            {bookings
              .filter(
                (booking) =>
                  (booking.is_item_owner || booking.can_decide) &&
                  booking.status !== "returned",
              )
              .map((booking) => (
                <li key={`owner-${booking.id}`}>
                  <strong>{booking.item_name}</strong>
                  <span>
                    {booking.start_date} through {booking.end_date}
                  </span>
                  <span>Requested by: {booking.borrower_label}</span>
                  <span>Status: {bookingStatusLabel[booking.status]}</span>
                  {contactFor(booking.id) && (
                    <span>
                      Contact email:{" "}
                      {contactFor(booking.id)!.counterparty_email}
                    </span>
                  )}
                  {(booking.is_item_owner || booking.is_borrower) &&
                    workflow(booking)}
                  {(booking.is_item_owner || booking.is_borrower) &&
                    reportForm(
                      "counterparty",
                      booking.id,
                      `counterparty for ${booking.item_name}`,
                    )}
                  {booking.status === "requested" && (
                    <div className="booking-actions">
                      <button
                        type="button"
                        aria-label={`Accept reservation for ${booking.item_name}`}
                        disabled={isPending(`booking-decision-${booking.id}`)}
                        onClick={() => void decideBooking(booking, "accepted")}
                      >
                        Accept
                      </button>
                      <button
                        type="button"
                        className="secondary"
                        aria-label={`Refuse reservation for ${booking.item_name}`}
                        disabled={isPending(`booking-decision-${booking.id}`)}
                        onClick={() => void decideBooking(booking, "refused")}
                      >
                        Refuse
                      </button>
                    </div>
                  )}
                </li>
              ))}
          </ul>
        )}
      </section>
      <section className="booking-requests" aria-labelledby="history-title">
        <h3 id="history-title">Returned transaction history</h3>
        {bookings.filter(
          (booking) =>
            booking.status === "returned" &&
            (booking.is_borrower || booking.is_item_owner),
        ).length === 0 ? (
          <p>No returned transactions yet.</p>
        ) : (
          <ul>
            {bookings
              .filter(
                (booking) =>
                  booking.status === "returned" &&
                  (booking.is_borrower || booking.is_item_owner),
              )
              .map((booking) => (
                <li key={`history-${booking.id}`}>
                  <strong>{booking.item_name}</strong>
                  <span>
                    {booking.start_date} through {booking.end_date}
                  </span>
                  <span>Status: {bookingStatusLabel[booking.status]}</span>
                  {workflow(booking)}
                </li>
              ))}
          </ul>
        )}
      </section>
      {adminCommunityIds.includes(selectedCommunityId) && (
        <section
          className="booking-requests"
          aria-labelledby="moderation-title"
        >
          <h3 id="moderation-title">Moderation queue</h3>
          {moderationReports.length === 0 ? (
            <p>No reports in this community.</p>
          ) : (
            <ul>
              {moderationReports.map((report) => (
                <li key={report.id}>
                  <strong>{report.target_label}</strong>
                  <span>
                    Status: {report.status === "open" ? "Open" : "Handled"}
                  </span>
                  <span>Reason: {moderationReasonLabel(report.reason)}</span>
                  {report.note && <span>Note: {report.note}</span>}
                  <span>
                    Submitted:{" "}
                    {new Date(report.created_at).toLocaleDateString()}
                  </span>
                  {report.action_taken && (
                    <span>Action: {report.action_taken}</span>
                  )}
                  {report.status === "open" && (
                    <div className="booking-actions">
                      <button
                        type="button"
                        disabled={isPending(`moderate-${report.id}`)}
                        onClick={() => void moderate(report, false)}
                      >
                        Mark handled
                      </button>
                      {report.target_type === "item" && (
                        <button
                          type="button"
                          className="secondary"
                          disabled={isPending(`moderate-${report.id}`)}
                          onClick={() => void moderate(report, true)}
                        >
                          Hide item
                        </button>
                      )}
                    </div>
                  )}
                </li>
              ))}
            </ul>
          )}
        </section>
      )}
      <h3 className="manage-title">List and manage your items</h3>
      {communities.length > 0 && (
        <form
          aria-busy={isPending("create-item")}
          onSubmit={(event) => void createItem(event)}
        >
          <label htmlFor="item-community">Community</label>
          <select id="item-community" name="community" required>
            {communities.map((community) => (
              <option key={community.id} value={community.id}>
                {community.name}
              </option>
            ))}
          </select>
          <label htmlFor="item-name">Item name</label>
          <input
            id="item-name"
            name="name"
            minLength={2}
            maxLength={80}
            required
          />
          <label htmlFor="item-category">Item category</label>
          <select id="item-category" name="category" required>
            {itemCategories.map((category) => (
              <option key={category.value} value={category.value}>
                {category.label}
              </option>
            ))}
          </select>
          <label htmlFor="item-description">Short description</label>
          <textarea
            id="item-description"
            name="description"
            minLength={1}
            maxLength={500}
            required
          />
          <fieldset>
            <legend>Loan terms</legend>
            <label>
              <input
                type="radio"
                name="terms"
                value="free"
                checked={!paid}
                onChange={() => setPaid(false)}
              />{" "}
              Free loan
            </label>
            <label>
              <input
                type="radio"
                name="terms"
                value="paid"
                checked={paid}
                onChange={() => setPaid(true)}
              />{" "}
              Price per day
            </label>
          </fieldset>
          {paid && (
            <>
              <label htmlFor="item-price">Price per day</label>
              <input
                id="item-price"
                name="price"
                inputMode="decimal"
                placeholder="4.50"
                required
                {...fieldErrorProps("item-price")}
              />
            </>
          )}
          <label htmlFor="item-photo">
            Item photo (JPEG, PNG, or WebP; maximum 5 MB)
          </label>
          <input
            id="item-photo"
            name="photo"
            type="file"
            accept="image/jpeg,image/png,image/webp"
            required
            {...fieldErrorProps("item-photo")}
          />
          <button type="submit" disabled={isPending("create-item")}>
            List item
          </button>
        </form>
      )}
      <div className="item-list">
        {ownItems.map((item) => (
          <article key={item.id} className="item-card">
            <h3>
              {item.name}
              {item.archived ? " — Archived" : ""}
            </h3>
            {photoUrls[item.id] && (
              <img src={photoUrls[item.id]} alt={`Photo of ${item.name}`} />
            )}
            <p>{item.description}</p>
            <p>
              {item.is_free
                ? "Free loan"
                : `${(item.price_per_day_cents! / 100).toFixed(2)} per day`}
            </p>
            <section aria-labelledby={`availability-${item.id}`}>
              <h4 id={`availability-${item.id}`}>Availability</h4>
              <p>
                The item is unavailable by default. Add the calendar dates when
                it is available; start and end dates are both included.
              </p>
              {availabilities.filter((range) => range.item_id === item.id)
                .length === 0 ? (
                <p>No availability ranges set.</p>
              ) : (
                <ul className="availability-list">
                  {availabilities
                    .filter((range) => range.item_id === item.id)
                    .map((range) => (
                      <li key={range.id}>
                        <span>{availabilityLabel(range)}</span>
                        <button
                          type="button"
                          className="secondary"
                          disabled={isPending(
                            `availability-remove-${range.id}`,
                          )}
                          onClick={() => void removeAvailability(range.id)}
                          aria-label={`Remove ${availabilityLabel(range)}`}
                        >
                          Remove
                        </button>
                      </li>
                    ))}
                </ul>
              )}
              <form
                aria-busy={isPending(`availability-add-${item.id}`)}
                onSubmit={(event) => void addAvailability(event, item.id)}
              >
                <label htmlFor={`availability-start-${item.id}`}>
                  Start date (included)
                </label>
                <input
                  id={`availability-start-${item.id}`}
                  name="start_date"
                  type="date"
                  required
                  {...fieldErrorProps(`availability-start-${item.id}`)}
                />
                <label htmlFor={`availability-end-${item.id}`}>
                  End date (included)
                </label>
                <input
                  id={`availability-end-${item.id}`}
                  name="end_date"
                  type="date"
                  required
                  {...fieldErrorProps(`availability-end-${item.id}`)}
                />
                <button
                  type="submit"
                  disabled={isPending(`availability-add-${item.id}`)}
                >
                  Add availability range
                </button>
              </form>
            </section>
            {item.owner_id === currentUserId && (
              <details>
                <summary>Edit item</summary>
                <form
                  aria-busy={isPending(`update-item-${item.id}`)}
                  onSubmit={(event) => void updateItem(event, item)}
                >
                  <label htmlFor={`name-${item.id}`}>Item name</label>
                  <input
                    id={`name-${item.id}`}
                    name="name"
                    defaultValue={item.name}
                    required
                  />
                  <label htmlFor={`category-${item.id}`}>Item category</label>
                  <select
                    id={`category-${item.id}`}
                    name="category"
                    defaultValue={item.category}
                  >
                    {itemCategories.map((category) => (
                      <option key={category.value} value={category.value}>
                        {category.label}
                      </option>
                    ))}
                  </select>
                  <label htmlFor={`description-${item.id}`}>
                    Short description
                  </label>
                  <textarea
                    id={`description-${item.id}`}
                    name="description"
                    defaultValue={item.description}
                    required
                  />
                  <fieldset>
                    <legend>Loan terms</legend>
                    <label>
                      <input
                        type="radio"
                        name="terms"
                        value="free"
                        defaultChecked={item.is_free}
                      />{" "}
                      Free loan
                    </label>
                    <label>
                      <input
                        type="radio"
                        name="terms"
                        value="paid"
                        defaultChecked={!item.is_free}
                      />{" "}
                      Price per day
                    </label>
                  </fieldset>
                  <label htmlFor={`price-${item.id}`}>
                    Price per day (leave blank for free)
                  </label>
                  <input
                    id={`price-${item.id}`}
                    name="price"
                    inputMode="decimal"
                    defaultValue={
                      item.price_per_day_cents === null
                        ? ""
                        : (item.price_per_day_cents / 100).toFixed(2)
                    }
                    {...fieldErrorProps(`price-${item.id}`)}
                  />
                  <label htmlFor={`photo-${item.id}`}>
                    Replace photo (optional; keep the same file format)
                  </label>
                  <input
                    id={`photo-${item.id}`}
                    name="photo"
                    type="file"
                    accept="image/jpeg,image/png,image/webp"
                    {...fieldErrorProps(`photo-${item.id}`)}
                  />
                  <button
                    type="submit"
                    disabled={isPending(`update-item-${item.id}`)}
                  >
                    Save changes
                  </button>
                  {!item.archived && (
                    <button
                      type="button"
                      className="secondary"
                      aria-label={`Archive ${item.name}`}
                      disabled={isPending(`archive-item-${item.id}`)}
                      onClick={() => void archive(item.id)}
                    >
                      Archive item
                    </button>
                  )}
                </form>
              </details>
            )}
          </article>
        ))}
      </div>
    </section>
  );
}
