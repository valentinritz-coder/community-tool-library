"use client";

/* eslint-disable @next/next/no-img-element -- private, short-lived signed Storage URLs cannot be statically optimized */

import type { FormEvent } from "react";
import { useEffect, useState } from "react";

import type { Community } from "../domain/community";
import {
  itemCategories,
  photoExtension,
  priceToCents,
  type Item,
} from "../domain/item";
import { getSupabaseBrowserClient } from "../infrastructure/supabase-browser";

interface ItemSectionProps {
  communities: Community[];
  currentUserId: string;
}

function messageFor(error: unknown): string {
  return error instanceof Error
    ? error.message
    : "The item could not be saved. Try again.";
}

export function ItemSection({ communities, currentUserId }: ItemSectionProps) {
  const [items, setItems] = useState<Item[]>([]);
  const [photoUrls, setPhotoUrls] = useState<Record<string, string>>({});
  const [message, setMessage] = useState("");
  const [paid, setPaid] = useState(false);

  async function refresh() {
    const supabase = getSupabaseBrowserClient();
    const result = await supabase
      .from("items")
      .select(
        "id,community_id,owner_id,name,category,description,photo_path,is_free,price_per_day_cents,archived",
      )
      .order("created_at", { ascending: false });
    if (result.error) throw result.error;
    const nextItems = result.data as Item[];
    const urls: Record<string, string> = {};
    await Promise.all(
      nextItems.map(async (item) => {
        const signed = await supabase.storage
          .from("item-photos")
          .createSignedUrl(item.photo_path, 300);
        if (!signed.error) urls[item.id] = signed.data.signedUrl;
      }),
    );
    setItems(nextItems);
    setPhotoUrls(urls);
  }

  useEffect(() => {
    const loadItems = window.setTimeout(() => {
      void refresh().catch((error: unknown) => setMessage(messageFor(error)));
    }, 0);
    return () => window.clearTimeout(loadItems);
  }, [communities]);

  async function createItem(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setMessage("");
    const form = new FormData(event.currentTarget);
    const photo = form.get("photo");
    if (!(photo instanceof File) || photo.size === 0) {
      setMessage("Choose one photo for the item.");
      return;
    }
    const extension = photoExtension(photo);
    if (!extension) {
      setMessage("Use a JPEG, PNG, or WebP photo.");
      return;
    }
    if (photo.size > 5 * 1024 * 1024) {
      setMessage("The photo must be 5 MB or smaller.");
      return;
    }
    const price = paid ? priceToCents(String(form.get("price") ?? "")) : null;
    if (paid && price === null) {
      setMessage("Enter a daily price between 0.01 and 1000.00.");
      return;
    }
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
      event.currentTarget.reset();
      setPaid(false);
      await refresh();
      setMessage("Item listed for your community.");
    } catch (error) {
      setMessage(messageFor(error));
    }
  }

  async function updateItem(event: FormEvent<HTMLFormElement>, item: Item) {
    event.preventDefault();
    setMessage("");
    const form = new FormData(event.currentTarget);
    const free = form.get("terms") === "free";
    const price = free ? null : priceToCents(String(form.get("price") ?? ""));
    if (!free && price === null) {
      setMessage("Enter a daily price between 0.01 and 1000.00.");
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
        setMessage(
          "The replacement must use the same JPEG, PNG, or WebP format and be 5 MB or smaller.",
        );
        return;
      }
    }
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
    if (result.error) setMessage(messageFor(result.error));
    else {
      if (replacement instanceof File && replacement.size > 0) {
        const uploaded = await getSupabaseBrowserClient()
          .storage.from("item-photos")
          .upload(item.photo_path, replacement, {
            contentType: replacement.type,
            upsert: true,
          });
        if (uploaded.error) {
          setMessage(messageFor(uploaded.error));
          return;
        }
      }
      await refresh();
      setMessage("Item changes saved.");
    }
  }

  async function archive(itemId: string) {
    const result = await getSupabaseBrowserClient()
      .from("items")
      .update({ archived: true })
      .eq("id", itemId);
    if (result.error) setMessage(messageFor(result.error));
    else {
      await refresh();
      setMessage("Item archived.");
    }
  }

  return (
    <section className="card wide" aria-labelledby="items-title">
      <h2 id="items-title">Community items</h2>
      <p className="notice" role="status" aria-live="polite">
        {message}
      </p>
      {communities.length > 0 && (
        <form onSubmit={(event) => void createItem(event)}>
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
          <label htmlFor="item-category">Safe category</label>
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
          />
          <button type="submit">List item</button>
        </form>
      )}
      <div className="item-list">
        {items.map((item) => (
          <article key={item.id} className="item-card">
            {photoUrls[item.id] && (
              <img src={photoUrls[item.id]} alt={`Photo of ${item.name}`} />
            )}
            <h3>
              {item.name}
              {item.archived ? " — Archived" : ""}
            </h3>
            <p>{item.description}</p>
            <p>
              {item.is_free
                ? "Free loan"
                : `${(item.price_per_day_cents! / 100).toFixed(2)} per day`}
            </p>
            {item.owner_id === currentUserId && (
              <details>
                <summary>Edit item</summary>
                <form onSubmit={(event) => void updateItem(event, item)}>
                  <label htmlFor={`name-${item.id}`}>Item name</label>
                  <input
                    id={`name-${item.id}`}
                    name="name"
                    defaultValue={item.name}
                    required
                  />
                  <label htmlFor={`category-${item.id}`}>Safe category</label>
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
                  />
                  <label htmlFor={`photo-${item.id}`}>
                    Replace photo (optional; keep the same file format)
                  </label>
                  <input
                    id={`photo-${item.id}`}
                    name="photo"
                    type="file"
                    accept="image/jpeg,image/png,image/webp"
                  />
                  <button type="submit">Save changes</button>
                  {!item.archived && (
                    <button
                      type="button"
                      className="secondary"
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
