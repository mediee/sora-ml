import config
import openai

openai.api_key = config.OPENAI_API_KEY


def run_conversation(messages):
    try:
        response = openai.ChatCompletion.create(
            model="gpt-3.5-turbo-0613",
            messages=messages,
            temperature=0,
        )

        return response.choices[0].message["content"].strip()
    except Exception as e:
        print(f"APIへのリクエストでエラーが発生しました: {e}")
        print(response)
        return None


if __name__ == "__main__":
    messages = [
        {
            "role": "system",
            "content": "As an AI assistant, follow the user's instructions.",
        },
        {"role": "user", "content": input("プロンプトを入力してください: ")},
    ]
    generated_text = run_conversation(messages)
    if generated_text is not None:
        print("生成されたテキスト:", generated_text)
