import Ember from 'ember';
import CoughDrop from '../../app';
import i18n from '../../utils/i18n';

export default Ember.Component.extend({ 
  didInsertElement: function() {
    this.draw();
  },
  draw: function() {
    var stats = this.get('usage_stats');
    var elem = this.get('element').getElementsByClassName('parts_of_speech_combinations')[0];
    
    CoughDrop.Visualizations.wait('speech-flow', function() {
      if(elem && stats && stats.get('parts_of_speech_combinations')) {
        var data = new window.google.visualization.DataTable();
        data.addColumn('string', 'From');
        data.addColumn('string', 'To');
        data.addColumn('number', 'Instances');
        var rows = [];
        
        var combos = stats.get('parts_of_speech_combinations');
        var colors = [];
        var new_combos = {};
        for(var idx in combos) {
          var split = idx.split(',');
          var key = split[0] + ", " + split[1];
          new_combos[key] = new_combos[key] || 0;
          new_combos[key] = new_combos[key] + combos[idx];
          if(split[2]) {
            key = " " + split[0] + "," + split[1] + " ";
            new_combos[key] = new_combos[key] || 0;
            new_combos[key] = new_combos[key] + combos[idx];
          }
        }
        var split_check = function(label) {
          var type = label.replace(/^\s+/, '').replace(/\s+$/, '');
          if(!colors[label]) {
            var color = CoughDrop.keyed_colors.find(function(c) { return c.types.indexOf(type) >= 0; });
            colors.push((color || {border: "#ccc"}).border);
            colors[label] = true;
          }
        };
        for(var idx in new_combos) {
          var split = idx.split(",");
          rows.push([split[0], split[1], new_combos[idx]]);
          split.forEach(split_check);
        }
        var options = {
          sankey: {
            node: {
              colors: colors
            }
          }
        };
        data.addRows(rows);
        var chart = new window.google.visualization.Sankey(elem);
        chart.draw(data, options);
      }
    });
  }.observes('usage_stats.draw_id')
});
