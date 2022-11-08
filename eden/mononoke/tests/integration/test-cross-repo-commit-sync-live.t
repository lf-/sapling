# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License found in the LICENSE file in the root
# directory of this source tree.

  $ . "${TEST_FIXTURES}/library.sh"
  $ . "${TEST_FIXTURES}/library-push-redirector.sh"

Setup configuration
  $ setup_configerator_configs
  $ cat > "$PUSHREDIRECT_CONF/enable" <<EOF
  > {
  > "per_repo": {
  >   "1": {
  >      "draft_push": false,
  >      "public_push": false
  >    }
  >   }
  > }
  > EOF

-- Init Mononoke thingies
  $ XREPOSYNC=1 init_large_small_repo
  Adding synced mapping entry
  Starting Mononoke server

-- Start up the sync job in the background
  $ mononoke_x_repo_sync_forever $REPOIDSMALL $REPOIDLARGE

Before the change
-- push to a small repo
  $ cd "$TESTTMP/small-hg-client"
  $ REPONAME=small-mon hgmn up -q master_bookmark
  $ mkdir -p non_path_shifting
  $ echo a > foo
  $ echo b > non_path_shifting/bar
  $ hg ci -Aqm "before config change"
  $ REPONAME=small-mon hgmn push -r . --to master_bookmark -q
  $ log 
  @  before config change [public;rev=2;bc6a206054d0] default/master_bookmark
  │
  o  first post-move commit [public;rev=1;11f848659bfc]
  │
  o  pre-move commit [public;rev=0;fc7ae591de0e]
  $

-- wait a little to give sync job some time to catch up
  $ wait_for_xrepo_sync 2
  $ flush_mononoke_bookmarks

-- check the same commit in the large repo
  $ cd "$TESTTMP/large-hg-client"
  $ REPONAME=large-mon hgmn pull -q
  $ REPONAME=large-mon hgmn up -q master_bookmark
  $ log -r master_bookmark
  @  before config change [public;rev=3;c76f6510b5c1] default/master_bookmark
  │
  ~
  $ REPONAME=large-mon hgmn log -r master_bookmark -T "{files % '{file}\n'}"
  non_path_shifting/bar
  smallrepofolder/foo

Make a config change
  $ update_commit_sync_map_first_option
-- try to create mapping commit with incorrect file - this should fail
  $ mononoke_admin_source_target $REPOIDLARGE $REPOIDSMALL crossrepo pushredirection change-mapping-version \
  > --author author \
  > --large-repo-bookmark master_bookmark \
  > --version-name new_version \
  > --dump-mapping-large-repo-path mapping.json 2>&1 | grep 'cannot dump'
  * cannot dump mapping to a file because path doesn't rewrite to a small repo (glob)
-- now fix the filename - it should succeed
  $ mononoke_admin_source_target $REPOIDLARGE $REPOIDSMALL crossrepo pushredirection change-mapping-version \
  > --author author \
  > --large-repo-bookmark master_bookmark \
  > --version-name new_version \
  > --dump-mapping-large-repo-path smallrepofolder_after/mapping.json &> /dev/null
  $ flush_mononoke_bookmarks

After the change
-- push to a small repo
  $ cd "$TESTTMP/small-hg-client"
  $ REPONAME=small-mon hgmn pull -q
  $ REPONAME=small-mon hgmn up -q master_bookmark
  $ echo a > boo
  $ echo b > non_path_shifting/baz
  $ hg ci -Aqm "after config change"
  $ REPONAME=small-mon hgmn push -r . --to master_bookmark -q
  $ cat mapping.json
  *generated by the megarepo bind, reach out to Source Control @ FB with any questions (glob)
  {
    "default_prefix": "smallrepofolder_after",
    "overrides": {
      "non_path_shifting": "non_path_shifting"
    }
  } (no-eol)
  $ log -r master_bookmark
  @  after config change [public;rev=4;*] default/master_bookmark (glob)
  │
  ~

-- wait a little to give sync job some time to catch up
  $ wait_for_xrepo_sync 4
  $ flush_mononoke_bookmarks

-- check the same commit in the large repo
  $ cd "$TESTTMP/large-hg-client"
  $ REPONAME=large-mon hgmn pull -q
  $ REPONAME=large-mon hgmn up -q master_bookmark
  $ log -r "master_bookmark^::master_bookmark"
  @  after config change [public;rev=5;*] default/master_bookmark (glob)
  │
  o  Changing synced mapping version to new_version for large-mon->small-mon sync [public;rev=4;*] (glob)
  │
  ~
  $ REPONAME=large-mon hgmn log -r master_bookmark -T "{files % '{file}\n'}"
  non_path_shifting/baz
  smallrepofolder_after/boo
-- check mapping
  $ cat smallrepofolder_after/mapping.json
  *generated by the megarepo bind, reach out to Source Control @ FB with any questions (glob)
  {
    "default_prefix": "smallrepofolder_after",
    "overrides": {
      "non_path_shifting": "non_path_shifting"
    }
  } (no-eol)
