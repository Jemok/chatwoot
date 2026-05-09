# Fix Applied: Account Model Attribute Error

## What Was Wrong (Second Issue)

```
ActionView::Template::Error (undefined method 'page_id' for an instance of Account)
```

The form was using `form_for` with an Account object, but trying to access attributes that only exist on the `Channel::FacebookPage` model:
- `page_id` ❌ (belongs to Channel::FacebookPage, not Account)
- `page_access_token` ❌ (belongs to Channel::FacebookPage, not Account)
- `user_access_token` ❌ (belongs to Channel::FacebookPage, not Account)
- `inbox_name` ❌ (should be passed as raw param, not Account field)

## Root Cause

`form_for(@account)` with form builder:
```erb
<%= form_for([:create_facebook_channel, namespace, page.resource]) do |f| %>
  <%= f.text_field :page_id %>  ❌ Looks for Account#page_id
```

This was trying to bind form fields to Account model attributes that don't exist!

## Solution

Changed to `form_tag` which submits raw parameters without model binding:
```erb
<%= form_tag(create_facebook_channel_super_admin_account_path(page.resource), method: :post) do %>
  <%= text_field_tag :page_id %>  ✅ Just submits params[:page_id]
```

## What Changed

**File**: `app/views/super_admin/accounts/_facebook_channel.html.erb`

| Before | After |
|--------|-------|
| `form_for` | `form_tag` |
| `f.label`, `f.text_field`, `f.password_field` | `label_tag`, `text_field_tag`, `password_field_tag` |
| Model binding (tries to access Account attributes) | Raw parameters (submits to controller as params) |

## How the Flow Works Now

1. User fills form with: `page_id`, `page_access_token`, `user_access_token`, `inbox_name`
2. Form submits to: `/super_admin/accounts/:id/create_facebook_channel`
3. Controller receives raw params: `params[:page_id]`, etc.
4. Controller creates the Channel::FacebookPage with those params ✅

## Verification

✅ Route exists and helper name is correct: `create_facebook_channel_super_admin_account_path`
✅ Controller method reads exact params: `params[:page_id]`, `params[:page_access_token]`, `params[:user_access_token]`, `params[:inbox_name]`
✅ Form now uses `*_tag` helpers for parameter submission
✅ No model binding conflicts

---

**Status**: ✅ Fixed
**Updated**: 2026-05-09

