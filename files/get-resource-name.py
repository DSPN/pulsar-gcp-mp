import sys
import yaml

resource = sys.argv[1]

manifest_path = "/data/manifest-expanded/chart.yaml"

with open(manifest_path, "r", encoding="utf-8") as stream:
    content = stream.read()

Deployment = 'Deployment'
Job = 'Job'
Prometheus = 'Prometheus'

for d in yaml.safe_load_all(content):
    if d and "kind" in d:
        if d['kind'] == Deployment:
            if (resource == 'grafana' and
                d['metadata']['name'].endswith('-grafana')):
                sys.stdout.write(d['metadata']['name'])
            elif (resource == 'prom-operator' and
                d['metadata']['name'].endswith('-operator'):
                sys.stdout.write(d['metadata']['name'])
        elif d['kind'] == Job:
            if (resource == 'admiss-create' and
                d['metadata']['name'].endswith('-admission-create')):
                sys.stdout.write(d['metadata']['name'])
            elif (resource == 'admiss-patch' and
                d['kind'] == Job and
                d['metadata']['name'].endswith('-admission-patch')):
                sys.stdout.write(d['metadata']['name'])
        elif d['kind'] == Prometheus and resource == 'prometheus':
            sys.stdout.write(d['metadata']['name'])

sys.stdout.flush()
sys.exit(0)
