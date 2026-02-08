import time
from openai import OpenAI, APIConnectionError

# ==============================================================================
# CONFIGURATION
# ==============================================================================
AGENTS = [
    {
        "name": "DeepSeek R1 (Reasoning)",
        "port": 8000,
        "model": "deepseek_reasoner",  # Matches --served-model-name
        "test_prompt": "Explain the concept of 'recursion' in one sentence."
    },
    {
        "name": "Qwen3 Coder (Coding)",
        "port": 8001,
        "model": "qwen3_coder",      # Matches --served-model-name
        "test_prompt": "Write a Python function to check if a number is prime."
    }
]

# ==============================================================================
# TEST RUNNER
# ==============================================================================
def run_health_check():
    print(f"{'='*60}")
    print("🚀 STARTING CLUSTER HEALTH CHECK")
    print(f"{'='*60}\n")

    for agent in AGENTS:
        print(f"Testing: {agent['name']} (Port {agent['port']})")
        print(f"Model ID: {agent['model']}")
        
        # Initialize OpenAI Client pointing to local vLLM
        # vLLM requires an API key argument, but "EMPTY" is standard for local.
        client = OpenAI(
            base_url=f"http://localhost:{agent['port']}/v1",
            api_key="EMPTY"
        )

        try:
            # 1. Start Timer
            start_time = time.time()

            # 2. Send Request
            response = client.chat.completions.create(
                model=agent['model'],
                messages=[
                    {"role": "user", "content": agent['test_prompt']}
                ],
                max_tokens=256,
                temperature=0.7
            )

            # 3. Stop Timer
            end_time = time.time()
            duration = end_time - start_time

            # 4. Extract Data
            content = response.choices[0].message.content
            # Usage stats are often included by vLLM
            total_tokens = response.usage.total_tokens if response.usage else "N/A"

            # 5. Print Results
            print(f"✅ STATUS:  ONLINE")
            print(f"⏱️  LATENCY: {duration:.4f}s")
            print(f"📊 TOKENS:  {total_tokens}")
            print(f"📝 OUTPUT:\n{'-'*20}")
            print(f"{content.strip()[:300]}...") # Truncate for cleaner logs
            print(f"{'-'*20}\n")

        except APIConnectionError:
            print(f"❌ STATUS:  OFFLINE (Connection Refused)")
            print(f"   Check if vLLM is running on port {agent['port']}.\n")
        except Exception as e:
            print(f"❌ STATUS:  ERROR")
            print(f"   Details: {e}\n")

if __name__ == "__main__":
    run_health_check()
