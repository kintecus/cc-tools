# /// script
# requires-python = ">=3.11"
# dependencies = ["mcp>=1.0", "httpx"]
# ///
"""Gemini image generation MCP server (nanobanana)."""

import base64
import mimetypes
import os
from datetime import datetime
from pathlib import Path

import httpx
from mcp.server.fastmcp import FastMCP, Image

mcp = FastMCP("gemini-image")

API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent"
DOWNLOADS = Path.home() / "Downloads"


def _default_path() -> str:
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    return str(DOWNLOADS / f"gemini_{ts}.png")


def _call_gemini(parts: list[dict], api_key: str) -> dict:
    resp = httpx.post(
        API_URL,
        headers={"x-goog-api-key": api_key, "Content-Type": "application/json"},
        json={
            "contents": [{"parts": parts}],
            "generationConfig": {"responseModalities": ["TEXT", "IMAGE"]},
        },
        timeout=120,
    )
    resp.raise_for_status()
    return resp.json()


def _extract_response(data: dict, output_path: str) -> list:
    """Extract image and text from Gemini response, save image to disk."""
    results = []
    text_parts = []
    image_saved = False

    for part in data.get("candidates", [{}])[0].get("content", {}).get("parts", []):
        if "text" in part:
            text_parts.append(part["text"])
        elif "inlineData" in part:
            img_bytes = base64.b64decode(part["inlineData"]["data"])
            out = Path(output_path)
            out.parent.mkdir(parents=True, exist_ok=True)
            out.write_bytes(img_bytes)
            image_saved = True
            results.append(Image(data=part["inlineData"]["data"], format="png"))

    description = "\n".join(text_parts) if text_parts else ""
    if image_saved:
        msg = f"Image saved to {output_path}"
        if description:
            msg += f"\n\n{description}"
        results.insert(0, msg)
    elif description:
        results.append(f"No image generated. Response: {description}")
    else:
        results.append("No image or text in response.")

    return results


@mcp.tool()
def generate_image(
    prompt: str,
    output_path: str = "",
    aspect_ratio: str = "",
) -> list:
    """Generate an image from a text prompt using Gemini.

    Args:
        prompt: Description of the image to generate.
        output_path: Where to save the PNG. Defaults to ~/Downloads/gemini_{timestamp}.png.
        aspect_ratio: Optional aspect ratio (e.g. "16:9", "9:16", "4:3", "3:4"). Default is square.
    """
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        return "Error: GEMINI_API_KEY environment variable is not set."

    full_prompt = prompt
    if aspect_ratio and aspect_ratio != "1:1":
        full_prompt += f" Generate in {aspect_ratio} aspect ratio."

    if not output_path:
        output_path = _default_path()

    parts = [{"text": full_prompt}]
    data = _call_gemini(parts, api_key)
    return _extract_response(data, output_path)


@mcp.tool()
def edit_image(
    prompt: str,
    source_image_path: str,
    output_path: str = "",
) -> list:
    """Edit an existing image using a text prompt and Gemini.

    Args:
        prompt: Description of the edit to apply.
        source_image_path: Path to the source image to edit.
        output_path: Where to save the result. Defaults to ~/Downloads/gemini_{timestamp}.png.
    """
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        return "Error: GEMINI_API_KEY environment variable is not set."

    src = Path(source_image_path)
    if not src.exists():
        return f"Error: Source image not found: {source_image_path}"

    mime_type = mimetypes.guess_type(str(src))[0] or "image/png"
    img_b64 = base64.b64encode(src.read_bytes()).decode()

    if not output_path:
        output_path = _default_path()

    parts = [
        {"inlineData": {"mimeType": mime_type, "data": img_b64}},
        {"text": prompt},
    ]
    data = _call_gemini(parts, api_key)
    return _extract_response(data, output_path)


if __name__ == "__main__":
    mcp.run(transport="stdio")
