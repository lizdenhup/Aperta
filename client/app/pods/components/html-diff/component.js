import Ember from 'ember';
import LazyLoader from 'tahi/lib/lazy-loader';
import ENV from 'tahi/config/environment';

export default Ember.Component.extend({
  classNames: ['html-diff'],

  // This is the text of the version being viewed (left dropdown)
  viewingText: null,

  // This is the text of the version we're comparing with (right dropdown)
  comparisonText: null,

  // This is the default if nothing else is set
  default: null,

  manuscriptDiff: false,

  // These are elements that contain sentences worth diffing individually.
  tokenizeInsideElements: ['div', 'p'],

  renderEquations: true,

  sentenceDelimiter: /([.!?,;]\s*)/g,

  manuscript: function() {
    if (!this.get('comparisonText')) {
      return this.get('viewingText') || this.get('default');
    } else {
      return this.diff();
    }
  }.property('comparisonText', 'viewingText'),

  diff() {
    // Calculate the diff
    let diff = this.getDiffer().diff(
      this.get('comparisonText'),
      this.get('viewingText') || this.get('default'));

    let processed = Array();
    if (this.get('manuscriptDiff')) {
      for (var i = 0; i < diff.length; i++) {
        if (diff[i].value.startsWith('<img'))
        {
          processed.push(diff[i]);
        }
        else if ((diff[i].removed && diff[i+1].added) || 
                 (diff[i].added && diff[i+1].removed)){
          let left = diff[i].value ? diff[i].value : '';
          let right = diff[i+1].value ? diff[i+1].value : '';
          left = left.replace(/<span>/,'').replace(/<\/span>/, '');
          right = right.replace(/<span>/,'').replace(/<\/span>/, '');
          let sentence = JsDiff.diffWords(
            left, right);
          i = i + 1;
          _.each(sentence, (chunk) => {
            chunk.value = '<span>' + chunk.value + '</span>';
            processed.push(chunk);
          });
        } else {
          processed.push(diff[i]);
        }
      }
    }
    // Style the diff
    return _.map(processed, (chunk) => {
      let html = this.addDiffStylingClass(chunk);
      return this.unForceValidHTML(html);
    }).join('');
  },

  getDiffer: function() {
    if (!this.differ) {
      this.differ = new JsDiff.Diff();
      var that = this;
      this.differ.tokenize = function(html) {
        let elements = $(html).toArray();
        let tokens = _.map(elements, that.tokenizeElement, that);
        tokens =  _.flatten(tokens);
        return tokens;
      };
    }

    return this.differ;
  },

  addDiffStylingClass(chunk) {
    let cssClass = null;
    if (chunk.added) {
      cssClass = 'added';
    } else if (chunk.removed) {
      cssClass = 'removed';
    } else {
      cssClass = 'unchanged';
    }

    let elements = $(chunk.value).addClass(cssClass).toArray();
    return _.pluck(elements, 'outerHTML').join('');
  },

  // TOKENIZING

  // For tags that we diff *inside* of, we will necessarily have
  // chunks that contain only the opening or only the closing tag. For
  // the sake of future manipulation, we need every chunk to be valid,
  // complete HTML.
  //
  // So (warning: gross parts ahead) for any tag we diff inside, we
  // replace the opening and closing tag with an *empty matched pair*.
  // Then, right before we spit the final diffed HTML back out, we
  // turn each matched pair back into a single opening or closing tag.
  //
  // Beatings, threats, and poison-pen notes can be sent to Sam
  // Bleckley. Sorry. - 08/06/2015

  forceValidHTML(element, tokens) {
    // Add the fake tag pairs
    let tagName = element.nodeName.toLowerCase();
    tokens.unshift('<fake-open-' + tagName + '></fake-open-' + tagName + '>');
    tokens.push('<fake-close-' + tagName + '></fake-close-' + tagName + '>');
  },

  unForceValidHTML: function(value) {
    // Remove the fake tag pairs
    _.each(this.tokenizeInsideElements, (elt) => {
      value = value.replace(
        (new RegExp('<fake-open-' + elt + '.*?>', 'g')), '<' + elt + '>');
      value = value.replace(
        (new RegExp('<fake-close-' + elt + '.*?>', 'g')), '</' + elt + '>');
      value = value.replace(
        (new RegExp('</fake-open-' + elt + '>', 'g')), '');
      value = value.replace(
        (new RegExp('</fake-close-' + elt + '>', 'g')), '');
    });
    return value;
  },

  shouldRecurseInto(element) {
    // Is this an element we want to diff inside (like a <p>), or
    // should we treat it atomically -- like a figure, or an equation?
    let name = element.nodeName.toLowerCase();
    return this.tokenizeInsideElements.indexOf(name) >= 0;
  },

  isTextNode(element) {
    return element.nodeType === 3;
  },

  tokenizeElement: function(element) {
    if (this.isTextNode(element)) {
      // Split the text into sentence fragments.
      let chunks = element.textContent.split(this.sentenceDelimiter);
      return _.map(chunks, (e) => { return '<span>' + e + '</span>'; });

    } else if (this.shouldRecurseInto(element)) {
      // Recurse within this element
      let elements = $(element).contents().toArray();
      let tokens = _.map(elements, this.tokenizeElement, this);
      this.forceValidHTML(element, tokens);
      return tokens;

    } else {
      return element.outerHTML;
    }
  },

  // MATHJAX (for rendering equations).

  loadMathJax: function() {
    LazyLoader.loadScripts([ENV.mathjax.url]).then(() => {
      this.refreshEquations();
    });
  },

  refreshEquations:  function() {
    if (!window.MathJax) { this.loadMathJax(); return; }
    else if (!window.MathJax.Hub) { return; }

    Ember.run.next(() => {
      MathJax.Hub.Queue(['Typeset', MathJax.Hub, this.$()[0]]);
    });
  }.observes('manuscript').on('didInsertElement')
});
