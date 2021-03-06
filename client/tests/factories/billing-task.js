/**
 * Copyright (c) 2018 Public Library of Science
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
*/

import FactoryGuy from 'ember-data-factory-guy';

FactoryGuy.define('billing-task', {
  default: {
    title: 'Billing',
    type: 'BillingTask',
    completed: false,

    nestedQuestions: [
      { id: 881, ident: 'plos_billing--first_name' },
      { id: 882, ident: 'plos_billing--last_name' },
      { id: 883, ident: 'plos_billing--title' },
      { id: 884, ident: 'plos_billing--department' },
      { id: 885, ident: 'plos_billing--affiliation1' },
      { id: 886, ident: 'plos_billing--affiliation2' },
      { id: 887, ident: 'plos_billing--phone_number' },
      { id: 888, ident: 'plos_billing--email' },
      { id: 889, ident: 'plos_billing--address1' },
      { id: 890, ident: 'plos_billing--address2' },
      { id: 891, ident: 'plos_billing--city' },
      { id: 892, ident: 'plos_billing--state' },
      { id: 893, ident: 'plos_billing--postal_code' },
      { id: 894, ident: 'plos_billing--country' },
      { id: 895, ident: 'plos_billing--payment_method' },
      { id: 896, ident: 'plos_billing--pfa_question_1' },
      { id: 897, ident: 'plos_billing--pfa_question_1a' },
      { id: 898, ident: 'plos_billing--pfa_question_1b' },
      { id: 899, ident: 'plos_billing--pfa_question_2' },
      { id: 900, ident: 'plos_billing--pfa_question_2a' },
      { id: 901, ident: 'plos_billing--pfa_question_2b' },
      { id: 902, ident: 'plos_billing--pfa_question_3' },
      { id: 903, ident: 'plos_billing--pfa_question_3a' },
      { id: 904, ident: 'plos_billing--pfa_question_4' },
      { id: 905, ident: 'plos_billing--pfa_question_4a' },
      { id: 906, ident: 'plos_billing--pfa_amount_to_pay' },
      { id: 907, ident: 'plos_billing--pfa_supporting_docs' },
      { id: 908, ident: 'plos_billing--pfa_additional_comments' },
      { id: 909, ident: 'plos_billing--affirm_true_and_complete' }
    ]
  }
});
