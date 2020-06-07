defmodule Drizzle.MixProject do
  use Mix.Project

  @app :drizzle
  @target System.get_env("MIX_TARGET") || :host
  @all_targets [:rpi, :rpi0, :rpi2, :rpi3, :rpi3a, :rpi4, :bbb, :x86_64]

  def project do
    [
      app: @app,
      version: "0.1.1",
      elixir: "~> 1.9",
      target: @target,
      archives: [nerves_bootstrap: "~> 1.6"],
      build_embedded: true,
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      releases: [{@app, release()}],
      preferred_cli_target: [run: :host, test: :host]
    ]
  end

  # Starting nerves_bootstrap adds the required aliases to Mix.Project.config()
  # Aliases are only added if MIX_TARGET is set.
  def bootstrap(args) do
    Application.start(:nerves_bootstrap)
    Mix.Task.run("loadconfig", args)
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Drizzle.Application, []},
      extra_applications: [:logger, :runtime_tools, :os_mon]
    ]
  end

  def release do
    [
      overwrite: true,
      cookie: "#{@app}_cookie",
      include_erts: &Nerves.Release.erts/0,
      steps: [&Nerves.Release.init/1, :assemble],
      strip_beams: Mix.env() == :prod,
      #applications: [:drizzle_ui]
      #applications: [drizzle_ui: :load]
    ]
  end

  defp aliases do
    [
      loadconfig: [&bootstrap/1],
      setup: ["deps.get", "cmd npm install --prefix drizzle_ui/assets"],
      assets: ["cmd npm run deploy --prefix drizzle_ui/assets"],
      firmware: ["assets", "firmware"]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:circuits_gpio, "~> 0.1"},
      {:cubdb, "~> 1.0.0-rc.3"},
      {:ecto, "~> 3.0"},
      {:finch, "~> 0.2.0"},
      {:jason, "~> 1.2.1"},
      #{:drizzle_ui, path: "drizzle_ui", runtime: false},
      {:drizzle_ui, path: "drizzle_ui"},
      {:nerves, "~> 1.6", runtime: false},
      {:shoehorn, "~> 0.6"},
      {:toolshed, "~> 0.2"},
      {:vintage_net, "~> 0.7.9"},
      {:vintage_net_wizard, "~> 0.2.3"},

      # Dependencies for all targets except :host
      {:nerves_time, "~> 0.2", targets: @all_targets},
      {:nerves_pack, "~> 0.3", targets: @all_targets},
      {:nerves_firmware_ssh, "~> 0.3", targets: @all_targets},
      {:nerves_runtime_shell, "~> 0.1.0", targets: @all_targets},
      {:ring_logger, "~> 0.8", targets: @all_targets},

      # Dependencies for specific targets
      {:nerves_system_rpi, "~> 1.11", runtime: false, targets: :rpi},
      {:nerves_system_rpi0, "~> 1.11", runtime: false, targets: :rpi0},
      {:nerves_system_rpi2, "~> 1.11", runtime: false, targets: :rpi2},
      {:nerves_system_rpi3, "~> 1.11", runtime: false, targets: :rpi3},
      {:nerves_system_rpi3a, "~> 1.11", runtime: false, targets: :rpi3a},
      {:nerves_system_rpi4, "~> 1.11", runtime: false, targets: :rpi4},
      {:nerves_system_bbb, "~> 2.6", runtime: false, targets: :bbb},
      {:nerves_system_x86_64, "~> 1.11", runtime: false, targets: :x86_64}
    ]
  end
end
