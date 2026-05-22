return {
  "rareitems/anki.nvim",
  -- lazy -- don't lazy it, it tries to be as lazy possible and it needs to add a filetype association
  opts = {
    {
      -- this function will add support for associating '.anki' extension with both 'anki' and 'tex' filetype.
      tex_support = false,
      models = {
        -- Here you specify which notetype should be associated with which deck
        NoteType = "GPUProgramming",
        ["Basic"] = "deckName:GPUProgramming",
        --["test"] = "GPU::ChildDeck",
      },
      contexts = nil, --(table | nil) Optional Table of context names as keys with value of table with `tags` and `fields`. See `:h anki.context`.
      move_cursor_after_creation = true, --(boolean) If `true` it will move the cursor the position of the first field
      -- linters = require("anki.linters").default_linters(), --(Linter[] | nil) Your linters see `:h anki.linter`
      -- transformers = nil, --(Transformer[] | nil) Your transformers `:h anki.transformer`
      -- tex_support = false, --(boolean) Basic support for latex inside the `anki` filetype. See |anki.texSupport|. xclip_path = "xclip", --(string | nil) Path to the `xclip` binary
      -- base64_path = "base64", --(string | nil) Path to the `base64` binary
    }
  }
}
