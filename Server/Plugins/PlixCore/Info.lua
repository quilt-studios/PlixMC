g_PluginInfo =
{
	Name = "PlixCore",
	Version = "1.0.0",
	Description = "Built-in gameplay suite: plots, economy, crates, checks and a configurable scoreboard.",
	Commands =
	{
		["/balance"] = { Permission = "plix.economy.balance", Handler = HandleBalance, HelpString = "Shows your balance" },
		["/pay"] = { Permission = "plix.economy.pay", Handler = HandlePay, HelpString = "Pays another player" },
		["/crate"] = { Permission = "plix.crates.open", Handler = HandleCrate, HelpString = "Opens a starter crate" },
		["/plot"] = { Permission = "plix.plots", Handler = HandlePlot, HelpString = "Claims or inspects a 16x16 plot" },
		["/servernameset"] = { Permission = "plix.admin.servername", Handler = HandleServerNameSet, HelpString = "Sets the PlixMC server name" },
	},
}
