export type UserTier = "standard" | "premium";
export type UserRole = "user" | "event_planner" | "admin";

export interface UserProfile {
  id: string;
  phone: string | null;
  email: string | null;
  name: string | null;
  city: string | null;
  photo_url: string | null;
  bio: string | null;
  is_verified: boolean;
  tier: UserTier;
  role: UserRole;
  created_at: string;
}

export type EventStatus = "draft" | "published" | "cancelled";

export interface EventRow {
  id: string;
  organizer_id: string;
  title: string;
  description: string | null;
  category: string;
  city: string;
  venue_name: string | null;
  lat: number | null;
  lng: number | null;
  start_time: string;
  end_time: string | null;
  price: number;
  capacity: number | null;
  cover_image_url: string | null;
  status: EventStatus;
  is_featured: boolean;
  premium_rsvp_opens_at: string | null;
  created_at: string;
}

export type HomeType = "apartment" | "house" | "private_room" | "shared_room";
export type HostVerificationStatus = "unverified" | "pending" | "verified";

export interface HostProfileRow {
  id: string;
  headline: string | null;
  about: string | null;
  home_type: HomeType | null;
  max_guests: number | null;
  house_rules: string | null;
  is_active: boolean;
  verification_status: HostVerificationStatus;
  city: string | null;
  lat: number | null;
  lng: number | null;
  created_at: string;
}

export interface HostPhotoRow {
  id: string;
  host_id: string;
  url: string;
  sort_order: number;
}

export type ReportTargetType = "event" | "user";
export type ReportStatus = "open" | "reviewing" | "resolved" | "dismissed";

export interface ReportRow {
  id: string;
  reporter_id: string;
  target_type: ReportTargetType;
  target_id: string;
  reason: string;
  status: ReportStatus;
  created_at: string;
}

export type ReviewSubjectType = "event" | "user";

export interface ReviewRow {
  id: string;
  subject_type: ReviewSubjectType;
  subject_id: string;
  reviewer_id: string;
  rating: number;
  text: string | null;
  created_at: string;
}

export const EVENT_CATEGORIES = [
  "Concert",
  "Meetup",
  "Workshop",
  "University",
  "Food Festival",
  "Sports",
  "Conference",
  "Other",
] as const;

export const CITIES = ["Karachi", "Lahore", "Islamabad", "Rawalpindi", "Faisalabad", "Peshawar"] as const;
