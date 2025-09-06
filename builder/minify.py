import re
import subprocess
import tempfile
import logging

LUASRCDIET_PATH = r"C:\Users\smokkkin\AppData\Roaming\luarocks\bin\luasrcdiet.bat"

def log_info(msg):
  logging.info(msg)

def log_warn(msg):
  logging.warning(msg)

def minify_lua_basic(code):
  code = re.sub(r"--.*", "", code)
  code = "\n".join([line.strip() for line in code.splitlines() if line.strip()])
  code = re.sub(r"\s+", " ", code)
  return code.strip()

def transform_gmod_for_luasrcdiet(code):
  string_pattern = r'(["\'])(?:\\.|(?!\1).)*\1'
  comment_pattern = r'--.*?$'
  protected = []

  def protect(m):
    protected.append(m.group(0))
    return f"__PROTECTED_{len(protected)-1}__"

  code_tmp = re.sub(string_pattern, protect, code, flags=re.MULTILINE)
  code_tmp = re.sub(comment_pattern, protect, code_tmp, flags=re.MULTILINE)

  code_tmp = re.sub(r'!=', '~=', code_tmp)
  code_tmp = re.sub(r'(?<![a-zA-Z0-9_])!(?!=)', 'not ', code_tmp)
  code_tmp = re.sub(r'(?<![a-zA-Z0-9_])continue(?![a-zA-Z0-9_])', 'return "__CONTINUEPOINT__"', code_tmp)

  def restore(m):
    idx = int(m.group(1))
    return protected[idx]

  return re.sub(r'__PROTECTED_(\d+)__', restore, code_tmp)

def minify_lua_luasrcdiet(code):
  try:
    with tempfile.NamedTemporaryFile("w+", delete=False, suffix=".lua") as tmp_in:
      tmp_in.write(code)
      tmp_in.flush()
      tmp_in_path = tmp_in.name

    tmp_out_path = tmp_in_path + "_min.lua"

    cmd = f'"{LUASRCDIET_PATH}" --maximum -o "{tmp_out_path}" "{tmp_in_path}"'
    log_info(f"Running LuaSrcDiet: {cmd}")
    process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, text=True)
    stdout, stderr = process.communicate()

    log_info(f"LuaSrcDiet stdout:\n{stdout}")
    log_info(f"LuaSrcDiet stderr:\n{stderr}")
    log_info(f"LuaSrcDiet returncode: {process.returncode}")

    if process.returncode != 0:
      log_warn(f"LuaSrcDiet failed, fallback to basic minify.")
      return minify_lua_basic(code)

    with open(tmp_out_path, "r", encoding="utf-8") as f:
      result = f.read()

    return result.strip()
  except Exception as e:
    log_warn(f"LuaSrcDiet exception, fallback to basic minify: {e}")
    return minify_lua_basic(code)

def revert_continue(code):
  code = re.sub(r'return\s*"__CONTINUEPOINT__"', ' continue ', code)
  return code

def flatten_to_one_line(code):
  code = re.sub(r'\s*\n\s*', ' ', code)
  code = re.sub(r'\s+', ' ', code)
  return code.strip()
