-- pandoc 3.8.2.1
-- Features: +server +lua
-- Scripting engine: Lua 5.4
-- clean_markdown.lua
-- Pandoc Lua filter to clean HTML for markdown output

local noise_classes = {
  "nav", "navigation", "menu", "sidebar", "ads", "ad", "advertisement",
  "script", "style", "footer", "header", "social", "share", "popup",
  "modal", "overlay", "comment", "breadcrumb", "pagination", "related",
  "widget", "sidebar", "promo", "subscribe", "newsletter"
}

local noise_ids = {
  "nav", "navigation", "sidebar", "ads", "footer", "header",
  "comments", "social", "menu", "popup", "related", "recommended"
}

local function is_noise_class(class)
  for _, noise in ipairs(noise_classes) do
    if class:match(noise) then
      return true
    end
  end
  return false
end

local function is_noise_id(id)
  for _, noise in ipairs(noise_ids) do
    if id == noise or id:match("^" .. noise) then
      return true
    end
  end
  return false
end

function Div(elem)
  for _, class in ipairs(elem.classes) do
    if is_noise_class(class) then
      return {}
    end
  end
  if is_noise_id(elem.identifier) then
    return {}
  end
  elem.attr = pandoc.Attr()
  return elem
end

function Span(elem)
  for _, class in ipairs(elem.classes) do
    if is_noise_class(class) then
      return {}
    end
  end
  if is_noise_id(elem.identifier) then
    return {}
  end
  elem.attr = pandoc.Attr()
  return elem
end

function RawBlock(elem)
  if elem.format == "html" then
    local text = elem.text:lower()
    if text:match("<script") or text:match("<style") or text:match("<!--") then
      return {}
    end
  end
  return elem
end

function RawInline(elem)
  if elem.format == "html" then
    local text = elem.text:lower()
    if text:match("<script") or text:match("<style") then
      return {}
    end
  end
  return elem
end

local keep_attrs = {
  href = true, src = true, alt = true, title = true,
  name = true, content = true
}

local function clean_attrs(attributes)
  local cleaned = {}
  for k, v in pairs(attributes) do
    if keep_attrs[k] then
      cleaned[k] = v
    end
  end
  return cleaned
end

function Link(elem)
  elem.attr.attributes = clean_attrs(elem.attr.attributes)
  return elem
end

function Image(elem)
  elem.attr.attributes = clean_attrs(elem.attr.attributes)
  return elem
end
