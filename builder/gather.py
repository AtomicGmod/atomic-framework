import os
import re
import logging

def log_info(msg):
  logging.info(msg)

def log_warn(msg):
  logging.warning(msg)

def read_file(path):
  if not os.path.exists(path):
    log_warn(f"File not found: {path}")
    return ""
  with open(path, "r", encoding="utf-8") as f:
    return f.read()

def gather_autorun(base_path):
  autorun_path = os.path.join(base_path, "lua", "autorun")
  if not os.path.exists(autorun_path):
    log_warn(f"Autorun directory not found: {autorun_path}")
    return ""
  all_code = ""
  for root, _, files in os.walk(autorun_path):
    for file in sorted(files):
      if file.endswith(".lua"):
        file_path = os.path.join(root, file)
        all_code += read_file(file_path) + "\n"
  return all_code

def process_includes(code, base_path):
  include_block_pattern = re.compile(r"---@include\s*(.*?)\n\n", re.DOTALL)
  func_call_pattern = re.compile(r'([a-zA-Z0-9_.]+)\s*\(\s*["\'](.+?)["\']')

  while True:
    match = include_block_pattern.search(code)
    if not match:
      break
    block = match.group(1)
    files_to_include = []
    for line in block.splitlines():
      line = line.strip()
      if not line:
        continue
      m = func_call_pattern.match(line)
      if m:
        path_arg = m.group(2)
        files_to_include.append(path_arg)
      else:
        log_warn(f"Could not parse include line: {line}")

    included_content = ""
    for f in files_to_include:
      fpath = os.path.join(base_path, f.replace("/", os.sep))
      included_content += read_file(fpath) + "\n"

    code = code[:match.start()] + included_content + code[match.end():]
  return code