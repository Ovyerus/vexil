%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "priv/", "test/"],
        excluded: []
      },
      color: true,
      checks: [
        {Credo.Check.Refactor.CyclomaticComplexity, false}
      ]
    }
  ]
}
