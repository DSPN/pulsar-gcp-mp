from argparse import ArgumentParser
import sys

import yaml

import helpers

valid_operations = (
    'find',
    'pull',
    'tag',
    'push',
    'remove',
    'publish',
)

image_map = {
    'luna-streaming': 'datastax/lunastreaming:2.8.0_1.1.11',
    'luna-streaming-all': 'datastax/lunastreaming-all:2.8.0_1.1.11',
}

class ImageFinder:

    known_registries = [
        'docker.io',
        'quay.io',
        'k8s.gcr.io'
    ]

    def count_whitespace(self, text):
        count = 0
        for i in text:
            if i.isspace():
                count += 1
            else:
                break
        return count

    class NotApplicableError(Exception):pass
    def extract_image(self, line, delim=':'):
        chars = ' \t"\''
        stripped = line.strip(chars)
        split = stripped.split(delim, maxsplit=1)
        try:
            path = split[1].strip(chars)
        except IndexError:
            raise NotApplicableError
        image = path.split(':')[0]
        tag = ':'.join(path.split(':')[1:])
        if image.split('/')[0] not in self.known_registries:
            image = "docker.io/" + image
        return f"{image}:{tag}"

    def find_images(self, template):
        images_section = False
        images_section_indent = 0
        for line in template.split('\n'):
            l = line.lower()
            if images_section:
                if self.count_whitespace(l) <= images_section_indent or \
                    not l.strip():
                    images_section = False
                    images_section_indent = 0
                else:
                    self.images.add(self.extract_image(l))
                    continue
            if 'image:' in l:
                self.images.add(self.extract_image(l))
                continue
            if 'quay.io' in l:
                try:
                    self.images.add(self.extract_image(l, delim='='))
                except NotApplicableError:
                    pass
            if 'images:' in l:
                images_section = True
                images_section_indent = self.count_whitespace(l)
                continue

    def __init__(self):
        self.images = set()

    def find(self):
        template = helpers.render_template()
        self.find_images(template)
        return sorted(self.images)


class ImagePuller:

    def pull(self):
        images = ImageFinder().find()

        for image in images:
            if 'docker.io' in image:
                image = image.replace('docker.io/', '')
            if '@sha256:' in image:
                path = image.split(':', maxsplit=1)
                image = path[0] + '@' + path[1].split('@')[1]
            cp = helpers.run(f"docker image ls -q {image}")
            if not cp.stdout and cp.returncode == 0:
                print(f"pulling image: {image}")
                cp = helpers.run(f"docker pull {image}")


class ImageTagger:

    def tag(self):
        version, short_version = helpers.get_versions()
        for name, image in image_map.items():
            print(f"tagging '{name}'")
            tag = ':'.join(image.split(':')[1:])
            cp = helpers.run(
                f"""
                docker tag {image} {helpers.dev_staging_repo}/{name}:{version}
                docker tag {image} {helpers.dev_staging_repo}/{name}:{short_version}
                """
                )
            if cp.returncode != 0:
                raise Exception(
                    f"""
                    Failed to tag image '{name}'
                    {cp.stdout}
                    """
                    )


class ImagePusher:

    def push(self):
        for name, image in image_map.items():
            print(f"pushing '{name}'")
            cp = helpers.run(
                f"""
                docker image push --all-tags {helpers.dev_staging_repo}/{name}
                """
                )
            if cp.returncode != 0:
                raise Exception(
                    f"""
                    failed to push image '{name}':
                    {cp.stdout}
                    """
                    )


class ImagePublisher:

    def publish(self, version):
        short_version = helpers.get_short_version(version)
        items = dict(image_map)
        items['deployer'] = 'deployer'
        for name in items.keys():
            dev_staging_name = f"{helpers.dev_staging_repo}/{name}"
            prod_staging_name = f"{helpers.prod_staging_repo}/{name}"
            print(f"creating tag. Source: '{dev_staging_name}', Dest: '{prod_staging_name}'")
            cp = helpers.run(
                f"""
                docker tag {dev_staging_name}:{version} {prod_staging_name}:{version}
                docker tag {dev_staging_name}:{version} {prod_staging_name}:{short_version}
                """
                )
            if cp.returncode != 0:
                raise Exception(
                    f"""
                    Failed to tag image '{name}'
                    {cp.stdout}
                    """
                    )
            print(f"pushing image versions for '{name}'")
            cp = helpers.run(
                f"""
                docker push {prod_staging_name}:{version}
                docker push {prod_staging_name}:{short_version}
                """
                )
            if cp.returncode != 0:
                raise Exception(
                    f"""
                    Failed to push image '{name}'
                    {cp.stdout}
                    """
                    )


class ImageRemover:

    def remove(self, version):
        short_version = helpers.get_short_version(version)
        for name, image in image_map.items():
            print(f"removing '{name}' from local repo")
            cp = helpers.run(
                f"""
                docker image rm {helpers.dev_staging_repo}/{name}:{version}
                docker image rm {helpers.dev_staging_repo}/{name}:{short_version}
                """
                )
            if cp.returncode != 0:
                print(
                    f"""
                    failed to remove image '{name}':
                    {cp.stdout}
                    """
                    )


def main():
    parser = ArgumentParser()
    parser.add_argument(
        '--operation',
        '-o',
        choices=valid_operations)
    parser.add_argument(
        '--version',
        '-v')

    args = parser.parse_args()

    if args.operation == 'find':
        for i in ImageFinder().find():
            print(i)

    if args.operation == 'pull':
        ImagePuller().pull()

    if args.operation == 'tag':
        ImageTagger().tag()

    if args.operation == 'push':
        ImagePusher().push()

    if args.operation == 'remove':
        if not args.version:
            print("<version> is required for the 'remove' operation")
            sys.exit(1)
        version = args.version
        ImageRemover().remove(version)

    if args.operation == 'publish':
        if not args.version:
            print("<version is required for the 'publish' operation")
            sys.exit(1)
        version = args.version
        ImagePublisher().publish(version)

if __name__ == '__main__':
    main()