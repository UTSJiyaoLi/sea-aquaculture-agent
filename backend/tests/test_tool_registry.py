from backend.app import registry


def test_registry_contains_reference_tools() -> None:
    assert registry.has("patent_fishi")
    assert registry.has("water_quality_mfpca")


def test_reference_tools_expose_metadata() -> None:
    patent = registry.get("patent_fishi").describe()
    mfpca = registry.get("water_quality_mfpca").describe()
    assert patent["status"] == "reference_only"
    assert patent["enabled_in_request_path"] is False
    assert "Patent_fishi.py" in patent["script_path"]
    assert mfpca["status"] == "reference_only"
    assert mfpca["enabled_in_request_path"] is False
    assert "MFPCA_paper.R" in mfpca["script_path"]
