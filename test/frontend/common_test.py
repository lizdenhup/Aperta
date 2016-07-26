#!/usr/bin/env python2
# -*- coding: utf-8 -*-
"""
POM Definition for the Tests common to all (or most) pages
"""

import logging
import os
import random
import time

from selenium.common.exceptions import TimeoutException

from Base.FrontEndTest import FrontEndTest
from Base.PostgreSQL import PgSQL
from Base.Resources import login_valid_pw, docs, users, editorial_users, external_editorial_users, \
    au_login, co_login, rv_login, ae_login, he_login, fm_login, oa_login
from Pages.login_page import LoginPage
from Pages.akita_login_page import AkitaLoginPage
from Pages.dashboard import DashboardPage
from Pages.manuscript_viewer import ManuscriptViewerPage


class CommonTest(FrontEndTest):
  """
  Common methods for all tests
  """

  def login(self, email='', password=login_valid_pw):
    """
    Used for Native Aperta Login, when enabled.
    :param email: used to force a specific user
    :param password: pw for user
    :return: DashboardPage
    """
    logins = (au_login['user'],
              co_login['user'],
              rv_login['user'],
              ae_login['user'],
              he_login['user'],
              fm_login['user'],
              oa_login['user'],
              # sa_login['user'],
              )
    if not email:
      email = random.choice(logins)
    # Login to Aperta
    logging.info('Logging in as user: {0}'.format(email))
    login_page = LoginPage(self.getDriver())
    login_page.enter_login_field(email)
    login_page.enter_password_field(password)
    login_page.click_sign_in_button()
    return DashboardPage(self.getDriver())

  def cas_login(self, email='', password=login_valid_pw):
    """
    Used for NED CAS login, when enabled.
    :param email: used to force a specific user
    :param password: pw for user
    :return: DashboardPage
    """
    logins = (users + editorial_users + external_editorial_users)
    if not email:
      user = random.choice(logins)
      email = user['email']
    # Login to Aperta
    logging.info('Logging in as user: {0}'.format(email))
    login_page = LoginPage(self.getDriver())
    login_page.login_cas()
    cas_signin_page = AkitaLoginPage(self.getDriver())
    cas_signin_page.enter_login_field(email)
    cas_signin_page.enter_password_field(password)
    cas_signin_page.click_sign_in_button()
    return DashboardPage(self.getDriver())

  @staticmethod
  def select_cas_user():
    """
    A method for selecting a single CAS user when needed to track which user was chosen
    :return: selected user dictionary
    """
    cas_users = (users, editorial_users, external_editorial_users)
    user = random.choice(cas_users)
    return user

  def select_preexisting_article(self, title='Hendrik', first=False):
    """
    Select a preexisting article.
    first is true for selecting first article in list.
    init is True when the user needs to logged in
    and needs to invoke login script to reach the homepage.
    """
    dashboard_page = DashboardPage(self.getDriver())
    # Need delay to ensure articles are attached to DOM
    time.sleep(1)
    if first:
      logging.debug('Clicking first pre-existent article')
      return dashboard_page.click_on_first_manuscript()
    else:
      return dashboard_page.click_on_existing_manuscript_link_partial_title(title)

  def create_article(self, title='', journal='journal', type_='Research1',
                     random_bit=False, doc='random'):
    """
    Create a new article.
    title: Title of the article.
    journal: Journal name of the article.
    type_: Type of article
    random_bit: If true, append some random string
    doc: Name of the document to upload. If blank will default to 'random', this will choose
    on of available papers
    Return the title of the article.
    """
    dashboard = DashboardPage(self.getDriver())
    # Create new submission
    title = dashboard.title_generator(prefix=title, random_bit=random_bit)
    logging.info('Creating paper in {0} journal, in {1} type with {2} as title'.format(journal,
                 type_, title))
    dashboard.enter_title_field(title)
    dashboard.select_journal_and_type(journal, type_)
    # This time helps to avoid random upload failures
    time.sleep(3)
    current_path = os.getcwd()
    # Download tests change dir to /tmp. If for some reason, they do not return to the correct
    #   directory, catch and abort - no good will follow
    assert current_path != '/tmp', 'WARN: Get current working directory returned ' \
                                   'incorrect value, aborting: {0}'.format(current_path)
    if doc == 'random':
      doc2upload = random.choice(docs)
      fn = os.path.join(current_path, 'frontend/assets/docs/{0}'.format(doc2upload))
    else:
      fn = os.path.join(current_path, 'frontend/assets/docs/', doc)
    logging.info('Sending document: {0}'.format(fn))
    time.sleep(1)
    self._driver.find_element_by_id('upload-files').send_keys(fn)
    dashboard.click_upload_button()
    # Time needed for script execution.
    time.sleep(7)
    return title

  def check_article(self, title, user='sealresq+1000@gmail.com'):
    """Check if article is in the dashboard"""
    dashboard = self.login(email=user)
    submitted_papers = dashboard._get(dashboard._submitted_papers)
    return True if title in submitted_papers.text else False

  def check_article_access(self, paper_url):
    """
    Check if current logged user has access to given article
    :paper_url: String with the paper url. Eg: http://aperta.tech/papers/22
    Returns True if the user has access and False when not
    """
    self._driver.get(paper_url)
    ms_page = ManuscriptViewerPage(self.getDriver())
    # change timeout
    ms_page.set_timeout(10)
    try:
      ms_page._get(ms_page._paper_title)
      ms_page.restore_timeout()
      return True
    except TimeoutException:
      ms_page.restore_timeout()
      return False

  @staticmethod
  def set_editors_in_db(paper_id):
    """
    Set up a handling editor, academic editor and cover editor for a given paper
    This is a temporary solution until these assignments can be done using the UI
    :paper_id: Integer with the paper id
    Returns None
    """
    # Set up a handling editor, academic editor and cover editor for this paper
    wombat_journal_id = PgSQL().query('SELECT id FROM journals WHERE name = \'PLOS Wombat\';')[0][0]
    handling_editor_role_for_env = PgSQL().query('SELECT id FROM roles WHERE journal_id = %s AND '
                                                 'name = \'Handling Editor\';',
                                                 (wombat_journal_id,))[0][0]
    cover_editor_role_for_env = PgSQL().query('SELECT id FROM roles WHERE journal_id = %s AND '
                                              'name = \'Cover Editor\';',
                                              (wombat_journal_id,))[0][0]
    academic_editor_role_for_env = PgSQL().query('SELECT id FROM roles WHERE journal_id = %s AND '
                                                 'name = \'Academic Editor\';',
                                                 (wombat_journal_id,))[0][0]

    handedit_user_id = PgSQL().query('SELECT id FROM users WHERE username = \'ahandedit\';')[0][0]
    covedit_user_id = PgSQL().query('SELECT id FROM users WHERE username = \'acoveredit\';')[0][0]
    acadedit_user_id = PgSQL().query('SELECT id FROM users WHERE username = \'aacadedit\';')[0][0]

    PgSQL().modify('INSERT INTO assignments (user_id, role_id, assigned_to_id, assigned_to_type, '
                   'created_at, updated_at) VALUES (%s, %s, %s, \'Paper\', now(), now());',
                   (handedit_user_id, handling_editor_role_for_env, paper_id))
    PgSQL().modify('INSERT INTO assignments (user_id, role_id, assigned_to_id, assigned_to_type, '
                   'created_at, updated_at) VALUES (%s, %s, %s, \'Paper\', now(), now());',
                   (covedit_user_id, cover_editor_role_for_env, paper_id))
    PgSQL().modify('INSERT INTO assignments (user_id, role_id, assigned_to_id, assigned_to_type, '
                   'created_at, updated_at) VALUES (%s, %s, %s, \'Paper\', now(), now());',
                   (acadedit_user_id, academic_editor_role_for_env, paper_id))
