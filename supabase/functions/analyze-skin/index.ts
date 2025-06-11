// supabase/functions/analyze-skin/index.ts

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { corsHeaders } from './_shared/cors.ts'

// Read the API key securely from the environment
const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY')

// The simpler, direct Gemini API endpoint
const GEMINI_API_URL = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=${GEMINI_API_KEY}`

const PROMPT = `
  Analyze the skin in this image as a professional dermatologist.
  Focus on visual cues like shininess, pore size, visible flakiness, or redness.
  Based on your analysis, classify the skin type into one of three categories: "Oily", "Dry", or "Normal".
  Your response MUST be ONLY one of those three words. Do not add any other explanation or punctuation.
  If the image is unclear, blurry, has heavy makeup, or you cannot determine the skin type for any reason, respond with the word "Uncertain".
`

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    if (!GEMINI_API_KEY) {
      throw new Error('GEMINI_API_KEY not set in Supabase secrets.')
    }
    
    const { image } = await req.json()

    if (!image) {
      return new Response(JSON.stringify({ error: 'Image base64 string is required.' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }})
    }
    
    const requestBody = {
      contents: [
        {
          parts: [
            { text: PROMPT },
            {
              inline_data: {
                mime_type: image.match(/data:([a-zA-Z0-9]+\/[a-zA-Z0-9-.+]+).*,.*/)?.[1],
                data: image.split(',')[1],
              },
            },
          ],
        },
      ],
    }

    const geminiResponse = await fetch(GEMINI_API_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(requestBody),
    })

    if (!geminiResponse.ok) {
      const errorBody = await geminiResponse.text()
      console.error('Gemini API error:', errorBody)
      throw new Error(`Gemini API request failed with status ${geminiResponse.status}`)
    }

    const responseData = await geminiResponse.json()
    const textResult = responseData.candidates[0]?.content?.parts[0]?.text?.trim()

    if (!textResult) {
      console.error('Could not parse text from Gemini response:', JSON.stringify(responseData))
      throw new Error('Could not parse skin type from Gemini response.')
    }
    
    const lowerCaseResult = textResult.toLowerCase();
    let finalSkinType = 'Uncertain';

    if (lowerCaseResult.includes('oily')) { finalSkinType = 'Oily'; } 
    else if (lowerCaseResult.includes('dry')) { finalSkinType = 'Dry'; } 
    else if (lowerCaseResult.includes('normal')) { finalSkinType = 'Normal'; }

    console.log(`Gemini raw response: "${textResult}", Parsed as: "${finalSkinType}"`);

    return new Response(JSON.stringify({ skinType: finalSkinType }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200,
    })
  } catch (error) {
    console.error('Error in Edge Function:', error.message)
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500,
    })
  }
})