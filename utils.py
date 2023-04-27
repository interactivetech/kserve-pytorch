import openai
import os
import json
def analyze_scene(json_d):
    '''
    '''
    prompt = f'''
    Generate only an informative and nature paragraph based on the json defined below. Show object, color and position. Use nouns rather than coordinates to show position information of each object. No more than 7 sentences. Only use one paragraph. Describe position of each object. Do not appear number. Don't mention in the description the json file.
    ```
    {json.dumps(json_d)}
    ```
    '''
    openai.api_key = "<FILLIN>"# supply your API key however you choose
    completion = openai.ChatCompletion.create(model="gpt-3.5-turbo", messages=[{"role": "user", "content": prompt}])
    # print(completion.choices[0].message.content)
    return completion