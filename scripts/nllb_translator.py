#!/usr/bin/env python3
"""
NLLB Local Translation Service
Lightweight NLLB model inference for Prezefren app
"""

import sys
import json
import os
import argparse
from pathlib import Path

try:
    from transformers import AutoTokenizer, AutoModelForSeq2SeqLM
    import torch
except ImportError:
    print(json.dumps({
        "error": "Missing dependencies. Install with: pip install transformers torch",
        "status": "dependency_error"
    }))
    sys.exit(1)

class NLLBTranslator:
    def __init__(self, model_path: str, device: str = "cpu"):
        """Initialize NLLB translator with local model"""
        self.model_path = model_path
        self.device = device
        self.model = None
        self.tokenizer = None
        self.loaded = False
        
        # NLLB language code mapping
        self.lang_codes = {
            "en": "eng_Latn",
            "es": "spa_Latn", 
            "fr": "fra_Latn",
            "de": "deu_Latn",
            "it": "ita_Latn",
            "pt": "por_Latn",
            "ru": "rus_Cyrl",
            "ja": "jpn_Jpan",
            "ko": "kor_Hang",
            "zh": "zho_Hans",
            "ar": "arb_Arab",
            "hi": "hin_Deva"
        }
    
    def load_model(self):
        """Load NLLB model and tokenizer"""
        try:
            if not os.path.exists(self.model_path):
                return {
                    "error": f"Model not found at {self.model_path}",
                    "status": "model_not_found"
                }
            
            print(json.dumps({"status": "loading", "message": "Loading NLLB model..."}), flush=True)
            
            # Load tokenizer and model
            self.tokenizer = AutoTokenizer.from_pretrained(self.model_path)
            self.model = AutoModelForSeq2SeqLM.from_pretrained(
                self.model_path,
                torch_dtype=torch.float16 if self.device != "cpu" else torch.float32,
                device_map="auto" if self.device != "cpu" else None
            )
            
            if self.device == "cpu":
                self.model = self.model.to("cpu")
            
            self.loaded = True
            return {"status": "loaded", "message": "NLLB model loaded successfully"}
            
        except Exception as e:
            return {
                "error": f"Failed to load model: {str(e)}",
                "status": "load_error"
            }
    
    def translate(self, text: str, source_lang: str = "en", target_lang: str = "es"):
        """Translate text using NLLB model"""
        if not self.loaded:
            load_result = self.load_model()
            if "error" in load_result:
                return load_result
        
        try:
            # Map language codes
            src_code = self.lang_codes.get(source_lang, "eng_Latn")
            tgt_code = self.lang_codes.get(target_lang, "spa_Latn")
            
            # Tokenize input
            inputs = self.tokenizer(
                text,
                return_tensors="pt",
                padding=True,
                truncation=True,
                max_length=512
            )
            
            if self.device != "cpu":
                inputs = {k: v.to(self.device) for k, v in inputs.items()}
            
            # Set target language
            forced_bos_token_id = self.tokenizer.lang_code_to_id[tgt_code]
            
            # Generate translation
            with torch.no_grad():
                outputs = self.model.generate(
                    **inputs,
                    forced_bos_token_id=forced_bos_token_id,
                    max_length=512,
                    num_beams=4,
                    early_stopping=True,
                    do_sample=False
                )
            
            # Decode translation
            translation = self.tokenizer.decode(outputs[0], skip_special_tokens=True)
            
            return {
                "status": "success",
                "translation": translation,
                "source_lang": source_lang,
                "target_lang": target_lang,
                "model": "nllb-200"
            }
            
        except Exception as e:
            return {
                "error": f"Translation failed: {str(e)}",
                "status": "translation_error"
            }

def main():
    parser = argparse.ArgumentParser(description="NLLB Translation Service")
    parser.add_argument("--model-path", required=True, help="Path to NLLB model directory")
    parser.add_argument("--device", default="cpu", help="Device to use (cpu, cuda, mps)")
    parser.add_argument("--interactive", action="store_true", help="Interactive mode")
    
    args = parser.parse_args()
    
    translator = NLLBTranslator(args.model_path, args.device)
    
    if args.interactive:
        # Interactive mode for testing
        print("NLLB Translator Interactive Mode")
        print("Enter 'quit' to exit")
        
        while True:
            try:
                text = input("Text: ").strip()
                if text.lower() == 'quit':
                    break
                
                source = input("Source language (en): ").strip() or "en"
                target = input("Target language (es): ").strip() or "es"
                
                result = translator.translate(text, source, target)
                print(json.dumps(result, indent=2))
                
            except KeyboardInterrupt:
                break
    else:
        # JSON-based communication for app integration
        try:
            # Read JSON input from stdin
            input_data = json.loads(sys.stdin.read())
            
            if input_data.get("action") == "load":
                result = translator.load_model()
            elif input_data.get("action") == "translate":
                result = translator.translate(
                    input_data["text"],
                    input_data.get("source_lang", "en"),
                    input_data.get("target_lang", "es")
                )
            else:
                result = {"error": "Unknown action", "status": "error"}
            
            print(json.dumps(result))
            
        except json.JSONDecodeError:
            print(json.dumps({
                "error": "Invalid JSON input",
                "status": "json_error"
            }))
        except Exception as e:
            print(json.dumps({
                "error": f"Unexpected error: {str(e)}",
                "status": "error"
            }))

if __name__ == "__main__":
    main()