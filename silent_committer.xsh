import re
import tqdm
import sys
from collections import Counter, defaultdict

# Example diff:
# diff --git a/accounts/permissions.py b/accounts/permissions.py
# index c478dd2cb..25e9fe20a 100644
# --- a/accounts/permissions.py
# +++ b/accounts/permissions.py
# @@ -43,7 +43,7 @@ class CacheValidatePermissions(object):
#          for pmap in PermissionMap.objects.all().values_list('permission__id', 'path_key'):
#              perms_maping[pmap[0]].append(pmap[1])
# 
# -        perms_needed = perms_maping.keys()
# +        perms_needed = list(perms_maping.keys())^M
#          permissions_dict = {}
# 
#          for user in User.objects.only('id').filter(is_staff=True, is_active=True):
# (1/2) Stage this hunk [y,n,q,a,d,j,J,g,/,e,?]?
# @@ -146,7 +146,7 @@ def get_user_premissions_cache_state(print_it=True):
#      data = cache_validator.all()
# 
#      if print_it:
# -        for user in User.objects.filter(id__in=data.keys()):
# +        for user in User.objects.filter(id__in=list(data.keys())):^M
#              print 'User ID', user.id, user.username, ':', data[user.id]
# 
#      return data
# (2/2) Stage this hunk [y,n,q,a,d,j,J,g,/,e,?]?

DIFF_FILE_PREFIX = 'diff --git a/'
DIFF_HUNK_PREFIX = '@@ -'
HUNK_INFO_REGEX = re.compile(r'(\d+),(\d+) \+(\d+),(\d+) @@') # Example: '@@ -43,7 +43,7 @@'
AUTHOR_NAME_REGEX = re.compile(r'^author (.*)$', re.MULTILINE)
AUTHOR_EMAIL_REGEX = re.compile(r'^author-mail \<(.*)\>$', re.MULTILINE)
CURRENT_AUTHOR = {'author_name': $(git config --global --get user.name).strip(), 'author_email': $(git config --global --get user.email).strip()}


def get_line_author(file_path, line):
    """
    Finds the name and email of the line's author.
    """
    blame_data = $(git blame @(file_path) -w -p -L @(line),@(line))
    
    return dict(
        author_name=AUTHOR_NAME_REGEX.findall(blame_data)[0],
        author_email=AUTHOR_EMAIL_REGEX.findall(blame_data)[0]
    )

def iterate_raw_hunks(git_diff):
    for file_diff in git_diff.split(DIFF_FILE_PREFIX)[1:]:
        file_path = file_diff.split(maxsplit=1)[0]
        diff_data = file_diff.split('\n', maxsplit=4)[4]
        hunks = {}

        for hunk_raw_data in diff_data.split(DIFF_HUNK_PREFIX)[1:]:
            hunk_info, hunk_diff = hunk_raw_data.split('\n', maxsplit=1)

            hunk_diff_lines = hunk_diff.split('\n')
            
            while not hunk_diff_lines[-1] or 'Split into' in hunk_diff_lines[-1] or hunk_diff_lines[-1] in ('\n', '\r', '\r\n'):
                hunk_diff_lines = hunk_diff_lines[:-1]

            hunk_diff, stage_info = '\n'.join(hunk_diff_lines[:-1]), hunk_diff_lines[-1]
            yield file_path, hunk_info, hunk_diff, stage_info


def parse_hunks():
    """
    Parse the git diff into hunks data
    """

    print('==== Parsing hunks from git diff ====')

    # Unstage all changes
    git reset > /dev/null

    # Split diff to maximum number of hunks
    ~/split_diff_to_maximum_hunks.sh > ~/silent_commiter_diff.txt 2>/dev/null 
    git_diff = open('/Users/ido/silent_commiter_diff.txt', 'rb').read().replace(b'\x0d\x0d\x0a', b'\n').decode()

    # Calculate the git diff
    split_commands = []

    # Parse hunks per file
    hunks_by_file = defaultdict(list)

    for file_path, hunk_info, hunk_diff, stage_info in iterate_raw_hunks(git_diff):
        if 's' in stage_info.split('Stage this hunk [')[1]:
            split_commands.append('s')
            continue

        split_commands.append('n')


        start_line, hunk_size = map(int, HUNK_INFO_REGEX.match(hunk_info).groups()[:2])

        # Filter out lines that were added   
        hunk_lines = (line for line in hunk_diff.splitlines() if not line.startswith('+'))
        hunk_data = dict(
            start_line=start_line,
            hunk_size=hunk_size,
            modified_lines=[(i + start_line) for i, line in enumerate(hunk_lines) if line.startswith('-')]
        )

        hunks_by_file[file_path].append(hunk_data)

    return hunks_by_file, split_commands
 

def iterate_hunks(hunks_by_file):
    """
    Generator of all the hunks.
    """
    for file_path, hunks in hunks_by_file.items():
        for hunk_index, hunk_data in enumerate(hunks):
            yield file_path, hunk_data, hunk_index


def calculate_hunks_authors(hunks_by_file):
    """
    Decides which author to use for each hunk for grouping the hunks into commits per author
    """
    print('==== Calculating author per changed hunk ====')
    # Iterate hunks and determine hunk author with progress bar
    for file_path, hunk_data, hunk_index in tqdm.tqdm(list(iterate_hunks(hunks_by_file))):

        # If hunk contains only added lines, than use current author.
        if not hunk_data['modified_lines']:
            hunk_data['author'] = CURRENT_AUTHOR
            continue

        modified_lines_authors = [get_line_author(file_path, modified_line) for modified_line in hunk_data['modified_lines']]
        modified_lines_author_emails = {author['author_email'] for author in modified_lines_authors}

        if len(modified_lines_author_emails) == 1:
            # Ther is only one original author for the changed lines in the hunk
            hunk_data['author'] = modified_lines_authors[0]
        else:
            # In case there are multiple original authors, we take the most contributing author for the hunk
            all_hunk_authors = [get_line_author(file_path, line) for line in range(hunk_data['start_line'], hunk_data['start_line'] + hunk_data['hunk_size'])]

            # Count how many lines each author wrote and filter out authors that didnt change any of the hunk changed lines
            lines_per_author = Counter(author['author_email'] for author in all_hunk_authors if author['author_email'] in modified_lines_author_emails)
            most_contributing_author_email = lines_per_author.most_common()[0][0]
            author_data = next(author for author in all_hunk_authors if author['author_email'] == most_contributing_author_email)
            hunk_data['author'] = author_data
            hunk_data['was_ambiguous'] = True

def remove_hunks(hunks_by_file, hunks_to_remove):
    for file_path, hunks_indices in hunks_to_remove.items():
        for hunk_index in hunks_indices[::-1]:
            del hunks_by_file[file_path][hunk_index]
        
        if not hunks_by_file[file_path]:
            del hunks_by_file[file_path]

def combine_split_and_stage_commands(split_commands, stage_commands):
    final_stage_commands = []
    index = 0
    for cmd in split_commands:
        if cmd == 's':
            final_stage_commands.append(cmd)
        else:
            final_stage_commands.append(stage_commands[index])
            index += 1
    
    return final_stage_commands

def commit_hunks_per_author(hunks_by_file):
    while hunks_by_file:
        current_hunks_by_file, split_commands = parse_hunks()
        file_path, file_hunks = next(iter(current_hunks_by_file.items()))
        first_hunk = file_hunks
        first_author = hunks_by_file[file_path][0]['author']

        

        stage_commands = []
        hunks_to_remove = defaultdict(list)
        for file_path, hunk_data, hunk_index in iterate_hunks(current_hunks_by_file):
            hunk_author = hunks_by_file[file_path][hunk_index]['author']
            if hunk_author['author_email'] == first_author['author_email']:
                stage_commands += 'y'
                hunks_to_remove[file_path].append(hunk_index)
            else:
                stage_commands += 'n'

        
        final_stage_commands = combine_split_and_stage_commands(split_commands, stage_commands)

        print(f"==== Staging hunks for author: {first_author['author_name']} <{first_author['author_email']}>")
        $(echo @('\n'.join(final_stage_commands) + '\n') | git add -p)
        # Remove hunks that were staged
        remove_hunks(hunks_by_file, hunks_to_remove)

        print(f"==== Committing hunks for author: {first_author['author_name']} <{first_author['author_email']}>")
        git commit -m @(f'{commit_msg}; For user: {hunk_author["author_name"]}') \
            --author=@(f"{hunk_author['author_name']} <{hunk_author['author_email']}>") &> /dev/null

def main():
    if not len(sys.argv) > 1:
        print('Usage: xonsh silent_commiter_diff.xsh <commit_msg>')
        exit(1)

    commit_msg = sys.argv[1]

    try:
        git config --global color.ui false
        hunks_by_file, _ = parse_hunks()
        

        # After we parsed the diff, we need to stash the changes so that we could get the original git blame info
        git stash > /dev/null

        try:
            calculate_hunks_authors(hunks_by_file)
        finally:
            git stash pop > /dev/null

        commit_hunks_per_author(hunks_by_file)
            
    finally:
        git config --global color.ui true
        rm ~/silent_commiter_diff.txt



if __name__ == '__main__':
    main()
