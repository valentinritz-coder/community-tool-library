#!/usr/bin/env bash
set -euo pipefail

database_url="${SUPABASE_LOCAL_DB_URL:-postgresql://postgres:postgres@127.0.0.1:54322/postgres}"
community_id="d1000000-0000-4000-8000-000000000001"
output="$(mktemp)"
trap 'rm -f "$output"' EXIT

if psql "$database_url" -X --set=ON_ERROR_STOP=1 --csv \
  -f scripts/pilot-metrics.sql >"$output" 2>/dev/null; then
  echo "pilot-metrics.sql unexpectedly accepted missing parameters" >&2
  exit 1
fi

psql "$database_url" -X --set=ON_ERROR_STOP=1 --csv \
  --set=community_id="$community_id" \
  --set=window_start="2000-01-01T00:00:00Z" \
  --set=window_end="2100-01-01T00:00:00Z" \
  -f scripts/pilot-metrics.sql >"$output"

node --input-type=module - "$output" <<'NODE'
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const [header, values, ...extra] = (await readFile(process.argv[2], "utf8"))
  .trimEnd()
  .split("\n");
assert.deepEqual(extra, []);

const columns = header.split(",");
const row = Object.fromEntries(columns.map((column, index) => [column, values.split(",")[index]]));
assert.deepEqual(columns, [
  "active_members_snapshot",
  "listings",
  "searches_not_currently_calculable",
  "useful_result_searches_not_currently_calculable",
  "booking_requests",
  "accepted_bookings",
  "completed_exchanges",
  "repeat_owners",
  "repeat_borrowers",
  "incidents_not_currently_calculable",
  "moderation_reports",
  "accepted_request_ratio",
  "completed_request_ratio",
  "repeat_owner_share",
  "repeat_borrower_share",
]);
assert.equal(row.searches_not_currently_calculable, "");
assert.equal(row.useful_result_searches_not_currently_calculable, "");
assert.equal(row.incidents_not_currently_calculable, "");
assert.equal(row.moderation_reports, "1");
assert.equal(row.completed_exchanges, "1");
assert.equal(row.repeat_owners, "0");
assert.equal(row.repeat_borrowers, "0");
console.log("Pilot metrics SQL parameters, columns, calculable counts, and explicit NULL gaps verified.");
NODE
