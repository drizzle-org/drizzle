defmodule Drizzle.MixProject do
  use Mix.Project

  @app :drizzle
  @target System.get_env("MIX_TARGET") || :host

  def project do
    [
      app: @app,
      version: "0.1.1",
      elixir: "~> 1.9",
      target: @target,
      archives: [nerves_bootstrap: "~> 1.6"],
      deps_path: "deps/#{@target}",
      build_path: "_build/#{@target}",
      lockfile: "mix.lock.#{@target}",
      start_permanent: Mix.env() == :prod,
      aliases: [loadconfig: [&bootstrap/1]],
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

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:circuits_gpio, "~> 0.1"},
      {:cubdb, "~> 1.0.0-rc.3"},
      {:finch, "~> 0.2.0"},
      {:jason, "~> 1.2.1"},
      #{:drizzle_ui, path: "drizzle_ui", runtime: false},
      {:drizzle_ui, path: "drizzle_ui"},
      {:nerves, "~> 1.6", runtime: false},
      {:shoehorn, "~> 0.6"},
      {:toolshed, "~> 0.2"},
    ] ++ deps(@target)
  end

  # Specify target specific dependencies
  defp deps(:host), do: []

  defp deps(target) do
    [
      {:nerves_time, "~> 0.2"},
      {:nerves_pack, "~> 0.3.0"},
      {:nerves_firmware_ssh, "~> 0.3"},
      {:nerves_runtime_shell, "~> 0.1.0"},
      {:ring_logger, "~> 0.8.0"},
      {:vintage_net, "~> 0.7.9"},
      {:vintage_net_wizard, "~> 0.2.3"}
    ] ++ system(target)
  end

  defp system("rpi"), do: [{:nerves_system_rpi, "~> 1.8", runtime: false}]
  defp system("rpi0"), do: [{:nerves_system_rpi0, "~> 1.8", runtime: false}]
  defp system("rpi2"), do: [{:nerves_system_rpi2, "~> 1.8", runtime: false}]
  defp system("rpi3"), do: [{:nerves_system_rpi3, "~> 1.8", runtime: false}]
  defp system("bbb"), do: [{:nerves_system_bbb, "~> 2.3", runtime: false}]
  defp system("ev3"), do: [{:nerves_system_ev3, "~> 1.8", runtime: false}]
  defp system("qemu_arm"), do: [{:nerves_system_qemu_arm, "~> 1.8", runtime: false}]
  defp system("x86_64"), do: [{:nerves_system_x86_64, "~> 1.8", runtime: false}]
  defp system(target), do: Mix.raise("Unknown MIX_TARGET: #{target}")
end
