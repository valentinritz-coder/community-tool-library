alter type public.booking_status add value 'checked_out';
alter type public.booking_status add value 'returned';

create type public.condition_phase as enum ('before', 'after');
