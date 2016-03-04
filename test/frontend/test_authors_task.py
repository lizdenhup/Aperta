#!/usr/bin/env python2
# -*- coding: utf-8 -*-
"""
This test case validates the Authors Task.
"""
__author__ = 'sbassi@plos.org'

from Base.Decorators import MultiBrowserFixture
from Base.Resources import login_valid_pw, staff_admin_login, super_admin_login, creator_login1, creator_login2, \
    creator_login3, creator_login4, creator_login5, reviewer_login, academic_editor_login, handling_editor_login, \
    internal_editor_login, pub_svcs_login
from frontend.Tasks.authors_task import AuthorsTask
from Pages.login_page import LoginPage
from Pages.manuscript_viewer import ManuscriptViewerPage
from frontend.common_test import CommonTest

import logging
import random
import time

users = [creator_login1,
         creator_login2,
         creator_login3,
         creator_login4,
         creator_login5,
         reviewer_login,
         handling_editor_login,
         academic_editor_login,
         internal_editor_login,
         staff_admin_login,
         pub_svcs_login,
         super_admin_login,
         ]

@MultiBrowserFixture
class AuthorsTaskTest(CommonTest):
  """
  Self imposed AC:
     - validate tasks elements and styles
     - validate adding and deleting an author
     - validate trying to close a task without completing author profile
  """

  def test_validate_components(self, init=True):
    """Validates styles for the author task"""
    user_type = random.choice(users)
    logging.info('Logging in as user: {}'.format(user_type))
    dashboard = self.cas_login() if init else DashboardPage(self.getDriver())
    title = self.create_article(journal='PLOS Wombat',
                                type_='Research',
                                )
    # Time needed for iHat conversion. This is not quite enough time in all circumstances
    time.sleep(10)
    manuscript_page = ManuscriptViewerPage(self.getDriver())
    manuscript_page.click_task('authors')
    authors_task = AuthorsTask(self.getDriver())
    authors_task.validate_styles()
    authors_task.validate_author_task_action()
    authors_task.validate_delete_author()
    authors_task.click_completed_checkbox()
    # Attempting to close authors task without a complete author should fail
    # Time for GUI to automatically unselect complete checkbox
    time.sleep(1)
    assert not authors_task.completed_cb_is_selected()
    authors_task.validate_completion_error()
    return self

if __name__ == '__main__':
  CommonTest._run_tests_randomly()
