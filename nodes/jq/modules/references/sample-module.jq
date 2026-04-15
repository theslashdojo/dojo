module {
  homepage: "https://jqlang.org/manual/v1.8/",
  purpose: "Example reusable jq helpers for Dojo modules",
  exports: ["normalize_name", "pick_release"]
};

def normalize_name:
  tostring
  | ascii_downcase
  | gsub("[^a-z0-9]+"; "-")
  | gsub("(^-+|-+$)"; "");

def pick_release:
  {tag: .tag_name, published: .published_at};
