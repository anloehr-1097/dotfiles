return {
	"attilarepka/header.nvim",
	config = function()
		require("header").setup({
			file_name = true,
			author = "Andreas Loehr",
			project = nil,
			date_created = true,
			date_created_fmt = "%Y-%m-%d %H:%M:%S",
			date_modified = true,
			date_modified_fmt = "%Y-%m-%d %H:%M:%S",
			line_separator = "------",
			copyright_text = "Copyright (c) 2025 Andreas Loehr",
			license_from_file = false,
		})
	end,
}
