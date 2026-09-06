# Forms & Controls

Inputs, buttons, forms, and interactive controls.

## Inputs

### Labels

Clicking the input label should focus the input field. Always associate labels with inputs:

```html
<label for="email">Email</label>
<input id="email" type="email" />

<!-- Or wrap the input -->
<label>
  Email
  <input type="email" />
</label>
```

### Input Types

Use appropriate `type` attributes:

```html
<input type="email" />
<input type="password" />
<input type="tel" />
<input type="url" />
<input type="number" />
<input type="search" />
```

### Autocomplete and Spellcheck

Set spellcheck and autocomplete for the field's purpose. Preserve browser/password-manager assistance for names, addresses, and credentials. For an identifier where spelling corrections are inappropriate:

```html
<input
  type="text"
  spellcheck="false"
  autocomplete="off"
/>
```

### 1Password Integration

Use password-manager exclusion attributes only for a field that is not a credential or personal-data field and is incorrectly identified. Do not disable password managers on authentication forms:

```html
<input data-lpignore="true" data-1p-ignore />
```

### Input Decorations

Prefix and suffix decorations (icons, labels) should be:
- Absolutely positioned on top of the text input with padding
- Not placed next to the input as siblings
- Should trigger focus on the input when clicked

```css
.input-wrapper {
  position: relative;
}

.input-icon {
  position: absolute;
  left: 12px;
  top: 50%;
  transform: translateY(-50%);
  pointer-events: none;
}

.input-field {
  padding-left: 40px;
}
```

For clickable icons (like clear button):

```jsx
<button
  type="button"
  aria-label="Focus search"
  className="input-icon-button"
  onClick={() => inputRef.current?.focus()}
>
  <SearchIcon />
</button>
```

### Font Size (iOS)

Ensure input font size is at least 16px to prevent zooming on iOS:

```css
input, textarea, select {
  font-size: 16px;
}
```

Inputs smaller than 16px cause iOS Safari to zoom in on focus.

### Autofocus

- Autofocus on inputs when a modal opens (if an input exists in the modal)
- Do NOT autofocus inputs on touch devices—it opens the keyboard unexpectedly

```jsx
// Let the installed dialog primitive manage focus on opening.
// Keep initial markup SSR-safe; do not read window during render.
<input aria-label="Search" />
```

## Forms

### Form Wrapper

Inputs should be wrapped with a `<form>` to submit by pressing Enter:

```html
<form onSubmit={handleSubmit}>
  <input type="text" />
  <button type="submit">Submit</button>
</form>
```

### Keyboard Submission

Ensure `Cmd+Enter` (Mac) / `Ctrl+Enter` (Windows) submits the form, especially for textareas. Attach this handler to the textarea; requestSubmit preserves native validation and the form submit event:

```jsx
function handleKeyDown(e) {
  if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {
    e.preventDefault();
    e.currentTarget.form?.requestSubmit();
  }
}
```

### Prefilling Forms

- Use logged-in user's data to prefill forms when possible
- When linking to a form, prefill content based on the request context

Example: If a user clicks "Change username", prefill with:
> "I'd like to change my username to:"

If you can prefill any user data based on the logged-in user, do that.

## Buttons

### Semantic Elements

A button should always be a `<button>`. Don't add click events on elements that aren't buttons:

```html
<!-- Good -->
<button onClick={handleClick}>Click me</button>

<!-- Bad -->
<div onClick={handleClick}>Click me</div>
<span onClick={handleClick}>Click me</span>
```

### Disabled After Submission

Disable buttons after submission to avoid duplicate network requests:

```jsx
const [isSubmitting, setIsSubmitting] = useState(false);
const [error, setError] = useState("");

<button
  type="button"
  disabled={isSubmitting}
  onClick={async () => {
    setIsSubmitting(true);
    setError(""); // Clear the previous attempt's error before retrying.
    try {
      await submitForm();
    } catch (error) {
      // Render an actionable error through the form's existing error state.
      setError(error instanceof Error ? error.message : "Could not submit. Try again.");
    } finally {
      setIsSubmitting(false);
    }
  }}
>
  {isSubmitting ? 'Submitting...' : 'Submit'}
</button>
{error && <p role="alert">{error}</p>}
```

### Button Shortcuts

If a button's action can also be performed with a keyboard shortcut, show that shortcut as a tooltip on the button:

```jsx
<Tooltip content="Save (Cmd+S)">
  <button onClick={save}>Save</button>
</Tooltip>
```

### Button Press Feel

An occasional button can use a small press scale when it matches the product's
motion language. Omit it for controls used constantly and when reduced motion
calls for a non-spatial response. Gate the effect explicitly rather than
applying it to every button:

```css
@media (prefers-reduced-motion: no-preference) {
  .button--press-scale:not(:disabled):active {
    transform: scale(0.97);
  }
}
```

## Checkboxes and Controls

### Dead Zones

Avoid dead zones on checkboxes and controls. The space between label and control should also be clickable:

```css
.checkbox-wrapper {
  display: flex;
  align-items: center;
  gap: 8px;
  cursor: pointer;
}

/* Make the entire row clickable, not just the checkbox */
.checkbox-wrapper label {
  cursor: pointer;
  flex: 1;
}
```

Or use a label that wraps everything:

```html
<label class="checkbox-row">
  <input type="checkbox" />
  <span>Remember me</span>
</label>
```

## Destructive Actions

Use confirmation for consequential irreversible actions; reversible actions can offer undo. Follow the product's existing behavior:

```jsx
function handleDelete() {
  if (confirm('Are you sure you want to delete this?')) {
    deleteItem();
  }
}
```

For better UX, use a proper confirmation modal instead of `confirm()`.

## Component Libraries

Use Base UI for accessible component primitives. If it doesn't fit the codebase, use whatever else fits, but ensure accessibility is maintained.

## Error Handling

Colocate errors—show error messages close to the field that caused them:

```jsx
<div className="field">
  <label htmlFor="contact-email">Email</label>
  <input id="contact-email" type="email" aria-invalid={!!error} aria-describedby={error ? "contact-email-error" : undefined} />
  {error && <span id="contact-email-error" className="error">{error}</span>}
</div>
```
