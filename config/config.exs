import Config

config :mpl3115a2,
  devices: [%{bus: "i2c-1", address: 0x60}]

config :git_ops,
  mix_project: Mix.Project.get!(),
  changelog_file: "CHANGELOG.md",
  repository_url: "https://gitlab.com/jimsy/mpl3115a2",
  manage_mix_version?: true,
  manage_readme_version: "README.md",
  version_tag_prefix: "v"
