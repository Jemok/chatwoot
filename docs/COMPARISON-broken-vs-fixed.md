# Visual: What Was Broken vs What's Fixed

## The Error You Saw

```
ActionView::Template::Error (undefined method 'page_id' for an instance of Account)
  app/views/super_admin/accounts/_facebook_channel.html.erb:15:in 'block in ...'
```

This means: Rails tried to call `Account#page_id` but that method doesn't exist!

---

## Root Cause: Model Binding Mismatch

### ❌ BROKEN CODE (What I did initially)
```erb
<!-- Tries to use Account object form -->
<%= form_for([:create_facebook_channel, namespace, page.resource], method: :post) do |f| %>

  <!-- This tries to access Account#page_id -->
  <%= f.text_field :page_id %>

  <!-- This tries to access Account#page_access_token -->
  <%= f.password_field :page_access_token %>

  <!-- This tries to access Account#user_access_token -->
  <%= f.password_field :user_access_token %>

  <!-- This tries to access Account#inbox_name -->
  <%= f.text_field :inbox_name %>
```

**Rails Form Builder Behavior:**
```
form_for(@account) + f.text_field(:page_id)
    ↓
Rails looks for: Account#page_id
    ↓
❌ Error: undefined method 'page_id'
```

---

## ✅ FIXED CODE (What Works Now)

```erb
<!-- Raw form submission, no model binding -->
<%= form_tag(create_facebook_channel_super_admin_account_path(page.resource), method: :post) do %>

  <!-- Just creates an HTML input named "page_id" -->
  <%= text_field_tag :page_id %>

  <!-- Just creates an HTML input named "page_access_token" -->
  <%= password_field_tag :page_access_token %>

  <!-- Just creates an HTML input named "user_access_token" -->
  <%= password_field_tag :user_access_token %>

  <!-- Just creates an HTML input named "inbox_name" -->
  <%= text_field_tag :inbox_name %>
```

**Form Tag Behavior:**
```
form_tag(...) + text_field_tag(:page_id)
    ↓
Creates: <input name="page_id" />
    ↓
Submits as: params[:page_id]
    ↓
✅ Controller receives the raw parameter
```

---

## The Key Difference

### form_for (Model Binding)
```
Form Builder tries to access model attributes
form_for(@account) + f.text_field(:page_id)
    ✓ Works if: Account has a page_id attribute
    ✗ Fails if: Account does NOT have page_id
```

### form_tag (Raw Parameters)
```
Form just creates HTML input elements
form_tag(...) + text_field_tag(:page_id)
    ✓ Always works - just creates HTML
    ✓ Submits raw params to controller
    ✗ No model binding = no attribute lookup
```

---

## Why The Controller Works Now

**Controller Code (unchanged):**
```ruby
def create_facebook_channel
  account = requested_resource
  page_id = params[:page_id]  # ✅ Gets raw param
  page_access_token = params[:page_access_token]  # ✅ Gets raw param
  user_access_token = params[:user_access_token]  # ✅ Gets raw param
  inbox_name = params[:inbox_name]  # ✅ Gets raw param

  # Creates Channel::FacebookPage (not Account!)
  facebook_channel = account.facebook_pages.create!(...)
```

The controller expects raw parameters (`params[:...]`), and `form_tag` provides exactly that!

---

## Data Flow Comparison

### ❌ BEFORE (Broken)
```
User fills form with: page_id, page_access_token, ...
          ↓
form_for tries to bind to Account object
          ↓
Rails looks for: @account.page_id
          ↓
❌ ERROR: undefined method 'page_id'
          ✗ Page never renders
          ✗ User sees hanging page
```

### ✅ AFTER (Fixed)
```
User fills form with: page_id, page_access_token, ...
          ↓
form_tag creates raw HTML inputs
          ↓
Form submits: params[:page_id], params[:page_access_token], ...
          ↓
Controller receives raw parameters
          ↓
Controller creates: Channel::FacebookPage.create!(...)
          ↓
✅ SUCCESS: Channel created!
```

---

## Summary

| Aspect | BEFORE ❌ | AFTER ✅ |
|--------|----------|---------|
| Form type | `form_for(@account)` | `form_tag` |
| Field helpers | `f.text_field(:page_id)` | `text_field_tag(:page_id)` |
| What happens | Rails looks for Account#page_id | Just creates HTML input |
| Result | ERROR: undefined method | Works! Submits params |
| User experience | Page hangs forever | Page loads & works immediately |

---

**Key Takeaway**: Use `form_tag` + `*_tag` helpers when your form parameters don't correspond to model attributes!

