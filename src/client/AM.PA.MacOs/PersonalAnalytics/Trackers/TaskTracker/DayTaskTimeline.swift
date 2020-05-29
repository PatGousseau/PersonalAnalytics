//
//  DayFragmentationTimeline.swift
//  PersonalAnalytics
//
//  Created by Chris Satterfield on 2017-05-31.
//
//  Adapted from Windows version created by André Meyer


class DayTaskTimeline: IVisualization{
    
    var title: String
    let color = AppConstants.retrospectiveColor
    var colorList = ["#FF9333", "#12A5F4", "#d3d3d3", "#99EBFF", "#A547D1"]
    var colorMap = [String: String]()
    var Size: String
    let timelineZoomFactor = 1
    var _type: [String] = [VisConstants.Day]
    
    required init() {
        title = "Timeline: Tasks over the Day"
        Size = "Wide"
    }
    
    func getHtml(_ _date: Date, type: String) -> String {
        
        if(!_type.contains(type)){
            return ""
        }
        
        var html = ""
        
        /////////////////////
        // fetch data sets
        /////////////////////
        let orderedTimelineList: [Task] = TaskQueries.GetDayTimelineData(date: _date);
        
        /////////////////////
        // data cleaning
        /////////////////////
        
        // show message if not enough data
        if (orderedTimelineList.count <= 3) // 3 is the minimum number of input-data-items
        {
            html += VisHelper.NotEnoughData()
            return html;
        }
        
        /////////////////////
        // Create HTML
        /////////////////////
        
        html += getTaskVisualizationContent(taskList: orderedTimelineList)
        
        return html
    }
    
    func getTaskIds(_ taskList: [Task]) -> [String]{
        var tasks: Set<String> = []
        for task in taskList{
            tasks.insert(task.taskId)
        }
        return Array(tasks).sorted()
    }
    
    func assignColor(_ taskId: String) -> String {
        if colorMap[taskId] == nil {
            colorMap[taskId] = colorList.randomElement()! //todo: handle error when all colors used
            if let index = colorList.index(of: colorMap[taskId]!) {
                colorList.remove(at: index)
            }
        }
        return colorMap[taskId]!
    }
    
    func GetHtmlColorForContextCategory(_ taskId: String) -> String{
        return assignColor(taskId)
    }
    
    func CreateJavascriptTaskDataList(taskList: [Task]) -> String{
        var html = ""
        
        let taskIds = getTaskIds(taskList)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "h:mm a"
        
        for taskId in taskIds
        {
            var times = ""
            for taskEntry in taskList where taskEntry.taskId == taskId
            {
                let startTime = taskEntry.startTime * 1000 //javascript time
                let endTime = taskEntry.endTime * 1000
                
                // add data used for the timeline and the timeline hover
                times += "{'starting_time': " + String(startTime) + ", 'ending_time': " + String(endTime)
                times +=    ", 'starting_time_formatted': '" + dateFormatter.string(from: Date(timeIntervalSince1970: taskEntry.startTime))
                times +=    "', 'ending_time_formatted': '" + dateFormatter.string(from: Date(timeIntervalSince1970: taskEntry.endTime))
                times +=    "', 'duration': " + String((taskEntry.duration / 60.0 * 10).rounded()/10)
                times +=    ", 'window_title': '" + taskEntry.name.replacingOccurrences(of: "'", with:"\\'")
                times +=    "', 'app': '" + taskEntry.name.replacingOccurrences(of: "'", with:"\\'")
                times +=    "', 'color': '" + GetHtmlColorForContextCategory(taskEntry.taskId)
                times +=    "', 'task': '" + taskEntry.taskId + "'}, "
            }
            
            html += "{class: '" + taskId + "', task: '" + taskId + "', times: [" + times + "]}, ";
        }
        
        return html;
    }
    
    func getTaskVisualizationContent(taskList: [Task]) -> String{
        let categories = getTaskIds(taskList)
        print(categories)
        let taskTimeline: String = "taskTimeline"
        let defaultHoverText = "Hint: Hover over the timeline to see details.";
        
        var html = ""
        
        /////////////////////
        // CSS
        /////////////////////
        
        html += "<style type='text/css'>\n"
        html += ".axis path,\n"
        html += ".axis line {\n"
        html += "    fill: none;\n"
        html += "    stroke: black;\n"
        html += "    shape-rendering: crispEdges;\n"
        html += "}\n"
        html += ".axis text {\n"
        html += "    font-size: .71em;\n"
        html += "    }\n"
        html += "    .timeline-label {\n"
        html += "        font-size: .71em;\n"
        html += "}\n"
        html += "</style>"
        
        /////////////////////
        // Javascript
        /////////////////////
        
        html += "<script type='text/javascript'>\n"
        //html += "var onLoad = window.onload;\n"
        //html += "window.onload = function() {\n"
        html += "window.addEventListener('load', function() { "
        
        // create formatted javascript data list
        html += "var data = [" + CreateJavascriptTaskDataList(taskList: taskList) + "]; "
        
        // create color scale
        html += CreateColorScheme(categories);
        
        // width & height
        html += "var itemWidth = 0.98 * document.getElementsByClassName('item Wide')[0].offsetWidth;";
        html += "var itemHeight = 0.15 * document.getElementsByClassName('item Wide')[0].offsetHeight;";
        
        // hover Event (d: current rendering object, i: index during d3 rendering, data: data object)
        var hover = ".hover(function(d, i, data) {\n"
        //hover += "console.log(d);\n"
        //hover += "console.log(data);\n"
        
        hover += "document.getElementById('hoverDetails').innerHTML = '<span style=\\'font-size:1.2em; color:#007acc;\\'>From ' + d['starting_time_formatted'] + ' to ' + d['ending_time_formatted'] + ' (' + d['duration'] + 'min)</span>' + '<br /><strong>Task</strong>: <span style=\\'color:' + d['color'] + '\\'>■</span> ' + d['task'] + '<br /><img style=\\'max-width:70%;max-height:auto;display:block;margin-left:auto;margin-right:auto\\' src=\\'test.png\\'/>';"
        
        hover += "console.log(d['task']);"
        
        for task in categories {
            hover += "if(d['task'] != \"" + task + "\") { d3.selectAll(\".timelineSeries_" + task + "\").style(\"opacity\", 0.1);}\n"
        }
        hover += "})"
                
        // mouseout Event
        var mouseout = ".mouseout(function (d, i, datum) { document.getElementById('hoverDetails').innerHTML = '" + defaultHoverText + "';\n"
        
        for task in categories {
            mouseout += "if(d['task'] != \"" + task + "\") { d3.selectAll(\".timelineSeries_" + task + "\").style(\"opacity\", 1);}\n"
        }
        
        mouseout += "})"
        
        // define configuration
        html += "var " + taskTimeline + " = d3.timeline().width(" + String(timelineZoomFactor)
        html += " * itemWidth).itemHeight(itemHeight)" + hover
        html += mouseout + ";";
        html += "var svg = d3.select('#" + taskTimeline
        html += "').append('svg').attr('width', itemWidth).datum(data).call(" + taskTimeline + "); ";
        html += "}); "; // end #1
        html += "</script>";
        
        /////////////////////
        // HTML
        /////////////////////
        
        // show details on hover
        html += "<div style='height:35%; style='align: center'><p id='hoverDetails'>" + defaultHoverText + "</p></div>";
        
        // add timeline
        html += "<div id='" + taskTimeline + "' align='center'></div>";
        
        // add legend
        html += GetLegendForCategories(categoryList: categories);
        
        print(html)
        return html;
    }
    
    func CreateColorScheme(_ categories: [String]) -> String{
        var rangeString = ""
        var taskString = ""
        for category in categories{
            rangeString += "'" + GetHtmlColorForContextCategory(category) + "', "
            taskString += "'" + category + "', "
        }
        
        let html = "var colorScale = d3.scale.ordinal().range([" + rangeString + "]).domain([" + taskString + "]); "
        
        return html
        
    }
    
    func GetLegendForCategories(categoryList: [String]) -> String{
        var html = ""
        html += "<style type='text/css'>\n"
        html += "#legend li { display: inline-block; padding-right: 1em; list-style-type: square; }\n"
        html += "li:before { content: '■ '}\n"
        html += "li span { font-size: .71em; color: black;}\n"
        html += "</style>"
        
        html += "<div><ul id='legend' align='center'>" // style='width:" + visWidth + "px'
        
        for category in categoryList where category != "Idle"{
            html += "<li style='color:" + GetHtmlColorForContextCategory(category) + "'><span>" + category + "</span></li>"
        }
        html += "</ul></div>"
        return html;
    }
    
    
    
}
