from setuptools import setup

# read the contents of your README file
from pathlib import Path
this_directory = Path(__file__).parent
long_description = (this_directory / "README.md").read_text()

setup(
    name='silent_committer',
    version='1.0.4',
    description='Commits changes as original authors',
    long_description=long_description,
    long_description_content_type='text/markdown',
    author='Ido Mozes',
    author_email='ido.mozes@gmail.com',
    url='https://github.com/idomoz/silent-committer',
    packages=['silent_committer'],
    package_data={
        'silent_committer': ['silent_committer.xsh', 'split_diff_to_maximum_hunks.sh'],
    },
    install_requires=[
        'tqdm',
        'xonsh',
    ],
    classifiers=[
        "Intended Audience :: Developers",
        "Operating System :: MacOS",
        "Operating System :: POSIX :: Linux",
        "Programming Language :: Python",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3 :: Only",
        "Programming Language :: Python :: 3.6",
        "Programming Language :: Python :: 3.7",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
    ],
    scripts=['bin/silently-commit'],
)
