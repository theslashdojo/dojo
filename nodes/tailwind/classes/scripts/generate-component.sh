#!/usr/bin/env bash
# Generate a Tailwind CSS component HTML snippet
# Usage: COMPONENT_TYPE=card ./generate-component.sh
# Env: COMPONENT_TYPE (required) - card|navbar|hero|form|footer|modal
#      OUTPUT_FILE (optional) - output file path, defaults to stdout

set -euo pipefail

COMPONENT_TYPE="${COMPONENT_TYPE:?COMPONENT_TYPE is required (card|navbar|hero|form|footer|modal)}"
OUTPUT_FILE="${OUTPUT_FILE:-}"

generate_card() {
  cat <<'HTML'
<div class="mx-auto max-w-sm overflow-hidden rounded-xl bg-white shadow-md dark:bg-gray-800">
  <img class="h-48 w-full object-cover" src="/placeholder.jpg" alt="Card image" />
  <div class="p-6">
    <div class="text-sm font-semibold uppercase tracking-wide text-indigo-500">Category</div>
    <h3 class="mt-1 text-lg font-medium leading-tight text-gray-900 dark:text-white">
      Card Title
    </h3>
    <p class="mt-2 text-sm text-gray-600 dark:text-gray-400">
      Card description text goes here. Keep it concise and informative.
    </p>
    <div class="mt-4">
      <button class="rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2">
        Action
      </button>
    </div>
  </div>
</div>
HTML
}

generate_navbar() {
  cat <<'HTML'
<nav class="border-b border-gray-200 bg-white dark:border-gray-700 dark:bg-gray-900">
  <div class="mx-auto flex max-w-7xl items-center justify-between px-4 py-3 sm:px-6 lg:px-8">
    <a href="/" class="text-xl font-bold text-gray-900 dark:text-white">Logo</a>
    <div class="hidden items-center gap-6 md:flex">
      <a href="/about" class="text-sm font-medium text-gray-600 hover:text-gray-900 dark:text-gray-300 dark:hover:text-white">About</a>
      <a href="/features" class="text-sm font-medium text-gray-600 hover:text-gray-900 dark:text-gray-300 dark:hover:text-white">Features</a>
      <a href="/pricing" class="text-sm font-medium text-gray-600 hover:text-gray-900 dark:text-gray-300 dark:hover:text-white">Pricing</a>
      <button class="rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700">
        Sign Up
      </button>
    </div>
    <button class="md:hidden" aria-label="Menu">
      <svg class="h-6 w-6 text-gray-600 dark:text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
      </svg>
    </button>
  </div>
</nav>
HTML
}

generate_hero() {
  cat <<'HTML'
<section class="bg-white dark:bg-gray-900">
  <div class="mx-auto max-w-7xl px-4 py-24 text-center sm:px-6 lg:px-8">
    <h1 class="text-4xl font-bold tracking-tight text-gray-900 dark:text-white sm:text-5xl lg:text-6xl">
      Build something amazing
    </h1>
    <p class="mx-auto mt-6 max-w-2xl text-lg text-gray-600 dark:text-gray-400">
      A compelling description that explains the value proposition clearly and concisely.
    </p>
    <div class="mt-10 flex items-center justify-center gap-4">
      <a href="/get-started" class="rounded-md bg-indigo-600 px-6 py-3 text-base font-medium text-white shadow-sm hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2">
        Get started
      </a>
      <a href="/learn-more" class="text-base font-medium text-indigo-600 hover:text-indigo-500 dark:text-indigo-400">
        Learn more →
      </a>
    </div>
  </div>
</section>
HTML
}

generate_form() {
  cat <<'HTML'
<form class="mx-auto max-w-md space-y-6 rounded-lg border border-gray-200 bg-white p-8 shadow-sm dark:border-gray-700 dark:bg-gray-800">
  <h2 class="text-xl font-semibold text-gray-900 dark:text-white">Sign In</h2>
  <div>
    <label for="email" class="block text-sm font-medium text-gray-700 dark:text-gray-300">Email</label>
    <input type="email" id="email" name="email" required
      class="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 shadow-sm focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white" />
  </div>
  <div>
    <label for="password" class="block text-sm font-medium text-gray-700 dark:text-gray-300">Password</label>
    <input type="password" id="password" name="password" required
      class="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 shadow-sm focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white" />
  </div>
  <div class="flex items-center justify-between">
    <label class="flex items-center gap-2">
      <input type="checkbox" class="rounded border-gray-300 text-indigo-600 focus:ring-indigo-500" />
      <span class="text-sm text-gray-600 dark:text-gray-400">Remember me</span>
    </label>
    <a href="/forgot" class="text-sm text-indigo-600 hover:text-indigo-500 dark:text-indigo-400">Forgot password?</a>
  </div>
  <button type="submit"
    class="w-full rounded-md bg-indigo-600 px-4 py-2.5 text-sm font-medium text-white hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2">
    Sign In
  </button>
</form>
HTML
}

generate_footer() {
  cat <<'HTML'
<footer class="border-t border-gray-200 bg-white dark:border-gray-700 dark:bg-gray-900">
  <div class="mx-auto max-w-7xl px-4 py-12 sm:px-6 lg:px-8">
    <div class="grid grid-cols-2 gap-8 md:grid-cols-4">
      <div>
        <h3 class="text-sm font-semibold uppercase tracking-wider text-gray-900 dark:text-white">Product</h3>
        <ul class="mt-4 space-y-3">
          <li><a href="/features" class="text-sm text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-white">Features</a></li>
          <li><a href="/pricing" class="text-sm text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-white">Pricing</a></li>
          <li><a href="/changelog" class="text-sm text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-white">Changelog</a></li>
        </ul>
      </div>
      <div>
        <h3 class="text-sm font-semibold uppercase tracking-wider text-gray-900 dark:text-white">Company</h3>
        <ul class="mt-4 space-y-3">
          <li><a href="/about" class="text-sm text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-white">About</a></li>
          <li><a href="/blog" class="text-sm text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-white">Blog</a></li>
          <li><a href="/careers" class="text-sm text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-white">Careers</a></li>
        </ul>
      </div>
      <div>
        <h3 class="text-sm font-semibold uppercase tracking-wider text-gray-900 dark:text-white">Support</h3>
        <ul class="mt-4 space-y-3">
          <li><a href="/docs" class="text-sm text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-white">Docs</a></li>
          <li><a href="/help" class="text-sm text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-white">Help Center</a></li>
          <li><a href="/contact" class="text-sm text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-white">Contact</a></li>
        </ul>
      </div>
      <div>
        <h3 class="text-sm font-semibold uppercase tracking-wider text-gray-900 dark:text-white">Legal</h3>
        <ul class="mt-4 space-y-3">
          <li><a href="/privacy" class="text-sm text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-white">Privacy</a></li>
          <li><a href="/terms" class="text-sm text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-white">Terms</a></li>
        </ul>
      </div>
    </div>
    <div class="mt-12 border-t border-gray-200 pt-8 dark:border-gray-700">
      <p class="text-center text-sm text-gray-500 dark:text-gray-400">&copy; 2025 Company. All rights reserved.</p>
    </div>
  </div>
</footer>
HTML
}

generate_modal() {
  cat <<'HTML'
<!-- Modal backdrop -->
<div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm">
  <!-- Modal panel -->
  <div class="relative mx-4 w-full max-w-lg rounded-xl bg-white p-6 shadow-xl dark:bg-gray-800">
    <!-- Close button -->
    <button class="absolute right-4 top-4 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300" aria-label="Close">
      <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
      </svg>
    </button>
    <!-- Content -->
    <h2 class="text-lg font-semibold text-gray-900 dark:text-white">Modal Title</h2>
    <p class="mt-2 text-sm text-gray-600 dark:text-gray-400">
      Modal content goes here. This is a centered modal with a backdrop blur overlay.
    </p>
    <!-- Actions -->
    <div class="mt-6 flex justify-end gap-3">
      <button class="rounded-md border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-300 dark:hover:bg-gray-600">
        Cancel
      </button>
      <button class="rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2">
        Confirm
      </button>
    </div>
  </div>
</div>
HTML
}

case "$COMPONENT_TYPE" in
  card)    output=$(generate_card) ;;
  navbar)  output=$(generate_navbar) ;;
  hero)    output=$(generate_hero) ;;
  form)    output=$(generate_form) ;;
  footer)  output=$(generate_footer) ;;
  modal)   output=$(generate_modal) ;;
  *)
    echo "Error: Unknown component type '$COMPONENT_TYPE'" >&2
    echo "Valid types: card, navbar, hero, form, footer, modal" >&2
    exit 1
    ;;
esac

if [ -n "$OUTPUT_FILE" ]; then
  echo "$output" > "$OUTPUT_FILE"
  echo "Component written to $OUTPUT_FILE"
else
  echo "$output"
fi
