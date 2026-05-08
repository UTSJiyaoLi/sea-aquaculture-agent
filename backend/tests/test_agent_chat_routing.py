from fastapi.testclient import TestClient

from backend.app import app


client = TestClient(app)


def test_agent_chat_routes_production_plan() -> None:
    response = client.post(
        "/api/agent/chat",
        json={"message": "帮我给A批鱼做未来30天规划，目标600g", "use_llm": False},
    )
    assert response.status_code == 200
    payload = response.json()
    assert payload["route"] == "production_plan"
    assert payload["intent"] == "production_plan"
    assert payload["plan_response"]["batch_id"] == "BATCH_A"


def test_agent_chat_routes_patent_tool() -> None:
    response = client.post(
        "/api/agent/chat",
        json={"message": "请调用专利模型 patent fishi 看一下生态生长参数"},
    )
    assert response.status_code == 200
    payload = response.json()
    assert payload["route"] == "patent_fishi"
    assert payload["tool_result"]["name"] == "patent_fishi"


def test_agent_chat_routes_mfpca_tool() -> None:
    response = client.post(
        "/api/agent/chat",
        json={"message": "我想做水质的MFPCA空间分析和主成分检查"},
    )
    assert response.status_code == 200
    payload = response.json()
    assert payload["route"] == "water_quality_mfpca"
    assert payload["tool_result"]["name"] == "water_quality_mfpca"
