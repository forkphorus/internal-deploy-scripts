import subprocess
import sys
from datetime import datetime

file = sys.argv[1]

with open(file, 'r') as f:
  contents = f.read()

  git_commit = subprocess.run(['git', 'rev-parse', '--verify', 'HEAD', '--short'], capture_output=True).stdout.decode('utf8').strip()
  date = datetime.now().strftime('%Y-%m-%d')
  version_text = f"Version {git_commit} ({date})"
  contents = contents.replace('</footer>', f' - {version_text}</footer>')

  google = '<meta name="google-site-verification" content="Re7zb-nm555twSGK216lVPDW-7v7ob1vQHYGQT3fBhE" />'
  monetization = '<meta name="monetization" content="$ilp.uphold.com/gF2KGUfLzqAR">'
  extra_head_tags = f'{google}{monetization}'
  contents = contents.replace('</head>', f'{extra_head_tags}</head>')

with open(file, 'w') as f:
  f.write(contents)
