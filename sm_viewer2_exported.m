classdef sm_viewer2_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        SingleMoleculeDataBrowserUIFigure  matlab.ui.Figure
        main_axis                    matlab.ui.control.UIAxes
        loadsmfcsvfileButton         matlab.ui.control.Button
        filename_loaded_label        matlab.ui.control.Label
        LoadeddataLabel              matlab.ui.control.Label
        targetSliderLabel            matlab.ui.control.Label
        targetSlider                 matlab.ui.control.Slider
        DataprocessorPanel           matlab.ui.container.Panel
        maxpxdisSpinnerLabel         matlab.ui.control.Label
        maxpxdisSpinner              matlab.ui.control.Spinner
        backgroundthresholdSpinnerLabel  matlab.ui.control.Label
        backgroundthresholdSpinner   matlab.ui.control.Spinner
        SpotfiltersPanel             matlab.ui.container.Panel
        numstatesSpinnerLabel        matlab.ui.control.Label
        numstatesSpinner             matlab.ui.control.Spinner
        minpointsSpinnerLabel        matlab.ui.control.Label
        minpointsSpinner             matlab.ui.control.Spinner
        minconsecutivepointsSpinnerLabel  matlab.ui.control.Label
        minconsecutivepointsSpinner  matlab.ui.control.Spinner
        netfoldchangeSpinnerLabel    matlab.ui.control.Label
        netfoldchangeSpinner         matlab.ui.control.Spinner
        exportButton                 matlab.ui.control.Button
        showsmoothedCheckBox         matlab.ui.control.CheckBox
        color_panel                  matlab.ui.container.Panel
        ApplyfilterstochannelsListBoxLabel  matlab.ui.control.Label
        channel_filter_list          matlab.ui.control.ListBox
    end

    
    properties (Access = public)
        original_loaded_data
        num_total_spots
        spot_rows
        num_total_fovs
        num_channels
        target_channel
        non_tchannel_rows
        
        num_frames
        
        adjusted_data
        filtered_spot_indices
        num_filtered_spots
        spot_view_index
        
        
        channel_colors
        channel_color_buttons
        channels_to_filter
    end
    
    methods (Access = public)
        
        function updateAllFields(app)
            
            if isempty(app.original_loaded_data)
                
                return;
            end
            
            app.adjusted_data = app.original_loaded_data;
            
            %adjust intensities of data based on criteria
            max_distance = app.maxpxdisSpinner.Value;
            if(max_distance <= 0)
                max_distance = Inf;
            end
            
            vals = app.original_loaded_data(:, 6:3:end);
            distances = app.original_loaded_data(:, 7:3:end);
            vals(distances > max_distance) = 0;
            app.adjusted_data(:, 6:3:end) = vals;
            
            %adjust intensities of data based on criteria
            bg_fraction = app.backgroundthresholdSpinner.Value;
            vals = app.adjusted_data(app.non_tchannel_rows, 6:3:end);
            bg = bg_fraction*app.original_loaded_data(app.non_tchannel_rows, 8:3:end);
            vals(vals < bg) = 0;
            app.adjusted_data(app.non_tchannel_rows, 6:3:end) = vals;
            
            %check for transition criteria
            app.filtered_spot_indices = [];
            old_num_filtered_spots = app.num_filtered_spots;
            if isempty(old_num_filtered_spots)
                old_num_filtered_spots = 0;
            end
            
            app.num_filtered_spots = 0;
            num_states = app.numstatesSpinner.Value;
            min_points = app.minpointsSpinner.Value;
            min_c_points = app.minconsecutivepointsSpinner.Value;
            fold_change = app.netfoldchangeSpinner.Value;
            
            for i = 1:app.num_total_spots
                
                intensities = app.adjusted_data(app.spot_rows{i}, 1:end);              
                intensities = intensities(intensities(:, 5) ~= app.target_channel & ismember(intensities(:, 5), app.channels_to_filter), 6:3:end);
     
                num_rows = size(intensities, 1);
                
                if sum(intensities > 0, "all") < min_points
                     continue;
                end
                
                longest_run = 0;
                run = 0;
                for r = 1:num_rows
                    
                    run = 0;
                    
                     for t = 1:size(intensities, 2)
                    
                        if (intensities(r, t) > 0)
                            run = run + 1;
                        else
                            if (run > longest_run) longest_run = run; end
                            run = 0;
                        end
                     end
                end
                
                if (run > longest_run) longest_run = run; end
               
                if (longest_run < min_c_points) continue; end
                
                if fold_change > 0
                    
                    found_larger_fc = false;
                    
                     for r = 1:size(intensities, 1)
                     
                         channel_intensities = intensities(r, :);
                         
                         if channel_intensities(1) < 0.001
                             
                             if channel_intensities(end) < 0.001
                                 
                                 fc = 1;
                             else
                                
                                  fc = 1e4;
                             end
                         else
                             
                             fc = channel_intensities(end)/channel_intensities(1);
                         end
                         
                         if fc > fold_change
                             
                             found_larger_fc = true;
                             break;
                         end
                     end
                
                     if found_larger_fc == false
                         continue;
                     end
                end
                
 
                if num_states > 0
              
                    found_num_states = false;
                    num_to_try = round(0.3*app.num_frames);

                    for r = 1:num_rows
                       
                        
                        data = intensities(r, :);
                        if max(data) == 0
                            continue;
                        end
                        data = data';
                        
                        [IDX,C,SUMD,K] = app.kmeans_opt(data, 5);
                        
                        if K == num_states
                         
                            found_num_states = true;
                            break;
                        end
                        
                    end
                    
                    if found_num_states == false
                        continue;
                    end
                end
                  
                app.num_filtered_spots = app.num_filtered_spots + 1;
                app.filtered_spot_indices(app.num_filtered_spots) = i;
            end
 
             %adjust possible slider values
             if app.num_filtered_spots < 2
                 
                 app.targetSlider.Visible = false;
                  if app.num_filtered_spots < 1
                      app.clearPlot();
                  else
                       app.spot_view_index = 1;
                       spot_data = app.adjusted_data(app.spot_rows{app.filtered_spot_indices(1)}, :);
                       app.displaySpotData(spot_data);
                  end
             else
                 
                  app.targetSlider.Visible = true;
                  app.targetSlider.Limits = [1 app.num_filtered_spots];
                  app.targetSlider.MajorTicks = [1 app.num_filtered_spots];
                  app.targetSlider.MinorTicks = 1:app.num_filtered_spots;
                  
                  if app.num_filtered_spots ~= old_num_filtered_spots
                  
                    app.spot_view_index = 1;
                  end
                  app.targetSlider.Value = app.spot_view_index;
                  spot_data = app.adjusted_data(app.spot_rows{app.filtered_spot_indices(app.spot_view_index)}, :);
                  app.displaySpotData(spot_data);
             end   
             
             app.SpotfiltersPanel.Title = sprintf("Spot filter: Remaining %i%%", round(100*app.num_filtered_spots/app.num_total_spots)); 
        end
        
        function displaySpotData(app, spot_data)
            
               app.clearPlot();
               
               show_smoothed = app.showsmoothedCheckBox.Value;
              
               fov_num = max(spot_data(:, 1));
               spot_id = max(spot_data(:, 2));
               spot_x = round(max(spot_data(:, 3)));
               spot_y = round(max(spot_data(:, 4)));
            
               title(app.main_axis, sprintf("FOV %i spot id %i (%i, %i)",fov_num, spot_id, spot_x, spot_y));
             
               hold(app.main_axis, 'on');
               for r = 1:size(spot_data, 1)
                 
                 color = app.channel_colors{spot_data(r, 5)};
                 primary_data = spot_data(r, 6:3:end);
                 line = plot(app.main_axis, primary_data, 'Color',color, 'LineWidth', 3);
                 
                 if show_smoothed == 1
                     
                     plot(app.main_axis, smoothdata(primary_data, 2, "movmean", 3),'Color', [line.Color 0.3], 'LineWidth', 2);
                 end
               end
               hold(app.main_axis, 'off');
               
               ymax = 1.2*max(spot_data(:, 6:3:end),[],'all');
               if ymax == 0
                   ymax = 100;
               end
               
               num_frames = round((size(spot_data, 2) - 5)/3);
               
               ylim(app.main_axis, [0 ymax])
               xlim(app.main_axis, [1 num_frames])
        end
        
        function clearPlot(app)
            
             plot_lines = findobj(app.main_axis, 'Type', 'line');
              if ~isempty(plot_lines)
                  delete(plot_lines);
              end       
        end
        
        function channelColorButtonWasPushed(app, event)
            
             button_title = event.Source.Text;             
             channel_num = sscanf(button_title,'channel %d');
             
             color = uisetcolor();
             
             if isempty(color)
                 return;
             end
             
             app.channel_color_buttons{channel_num}.FontColor = color;
             app.channel_colors{channel_num} = color;
             
             spot_data = app.adjusted_data(app.spot_rows{app.filtered_spot_indices( app.spot_view_index)}, :);
             app.displaySpotData(spot_data);
        end
        
        function [IDX,C,SUMD,K] = kmeans_opt(app, X, num_clusters)
           

            Cutoff=0.95; 
            Repeats=3;
            %unit-normalize
            
            assignin('base', 'beforeX', X);
            MIN=min(X); MAX=max(X); 
            X=(X-MIN)./(MAX-MIN);
            
            assignin('base', 'X', X);
            D=zeros(num_clusters,1); %initialize the results matrix
            for c=1:num_clusters %for each sample
                [~,~,dist]=kmeans(X,c,'emptyaction','drop'); %compute the sum of intra-cluster distances
                tmp=sum(dist); %best so far
                
                for cc=2:Repeats %repeat the algo
                    [~,~,dist]=kmeans(X,c,'emptyaction','drop');
                    tmp=min(sum(dist),tmp);
                end
                D(c,1)=tmp; %collect the best so far in the results vecor
            end
            Var=D(1:end-1)-D(2:end); %calculate %variance explained
            PC=cumsum(Var)/(D(1)-D(end));
            [r,~]=find(PC>Cutoff); %find the best index
            K=1+r(1,1); %get the optimal number of clusters
            [IDX,C,SUMD]=kmeans(X,K); %now rerun one last time with the optimal number of clusters
            C=C.*(MAX-MIN)+MIN;
        end
    end    

    % Callbacks that handle component events
    methods (Access = private)

        % Button pushed function: loadsmfcsvfileButton
        function loadsmfcsvfileButtonPushed(app, event)
            
           [filename, path] = uigetfile('*smf*.csv', 'Select file', 'MultiSelect', 'off');
           app.filename_loaded_label.Text = filename;
           
           cd(path);
           
           data = readtable(filename);
           data = data{:, :};
           app.spot_rows = {};
           
           app.num_channels = max(data(:, 5));
           for i = 1:app.num_channels
               
               if(sum(data(data(:, 5) == i, 7:3:end), 'all') == 0)
                   
                   app.target_channel = i;
                   break;
               end
           end
           
           app.non_tchannel_rows = data(:, 5) ~= app.target_channel;
           
            max_fov_num = max(data(:, 1));
            
            for f = 1:max_fov_num
                
                fov_data = data(data(:, 1) == f, :);
                if isempty(fov_data) 
                    continue
                end
                
                app.num_total_fovs = app.num_total_fovs + 1;
                
                max_spot_id = max(fov_data(:, 2));
                for s = 1:max_spot_id
                     app.spot_rows{end + 1} = find(data(:, 1) == f & data(:, 2) == s);
                end
            end
            
            app.num_total_spots = length(app.spot_rows);
            app.original_loaded_data = data;
            
            app.num_frames = round((size(app.original_loaded_data, 2) - 5)/3);
            
            app.channel_color_buttons = {};
            
            app.channel_colors = {'green', 'blue', 'magenta'};
            app.channel_colors = {'blue', 'magenta', 'green'};
            
            channel_names = {};
            channel_nums = {};
            app.channels_to_filter = [];
            
            for i = 1:app.num_channels
                
              btn = uibutton(app.color_panel,'Position',[10 320 - 45*i 120 22],'Text',sprintf('channel %i', i), "FontColor",app.channel_colors{i}, 'FontWeight','bold');
              btn.ButtonPushedFcn = createCallbackFcn(app, @channelColorButtonWasPushed, true);
              app.channel_color_buttons{end + 1} = btn;
              
              if(i ~= app.target_channel)
                  channel_names{end + 1} = sprintf('channel %i', i);
                  channel_nums{end + 1} = i;
              end
            end
            
            app.channel_filter_list.Items = channel_names;
            app.channel_filter_list.ItemsData = channel_nums;
            app.channels_to_filter = cell2mat(channel_nums);
            
            app.minconsecutivepointsSpinner.Limits = [0 app.num_frames];

            app.updateAllFields();
        end

        % Value changed function: maxpxdisSpinner
        function maxpxdisSpinnerValueChanged(app, event)
            value = app.maxpxdisSpinner.Value;
            app.updateAllFields();
        end

        % Value changed function: numstatesSpinner
        function numstatesSpinnerValueChanged(app, event)
            value = app.numstatesSpinner.Value;
            
            app.updateAllFields();
        end

        % Value changing function: targetSlider
        function targetSliderValueChanging(app, event)
            changingValue = event.Value;

            app.spot_view_index = round(changingValue);
            spot_data = app.adjusted_data(app.spot_rows{app.filtered_spot_indices( app.spot_view_index)}, :);
            app.displaySpotData(spot_data);
        end

        % Value changed function: backgroundthresholdSpinner
        function backgroundthresholdSpinnerValueChanged(app, event)
            value = app.backgroundthresholdSpinner.Value;
            app.updateAllFields();
        end

        % Value changed function: minpointsSpinner
        function minpointsSpinnerValueChanged(app, event)
            value = app.minpointsSpinner.Value;
            app.updateAllFields();
        end

        % Key press function: SingleMoleculeDataBrowserUIFigure
        function SingleMoleculeDataBrowserUIFigureKeyPress(app, event)
            key = event.Key;
            
            if strcmp(key, 'rightarrow')
                
                app.spot_view_index = app.spot_view_index + 1;
                if(app.spot_view_index > app.num_filtered_spots)
                    
                    app.spot_view_index = app.num_filtered_spots;
                end
                
            elseif strcmp(key,'leftarrow')
                    
                 app.spot_view_index = app.spot_view_index -1;
                 if(app.spot_view_index < 1)
                    
                    app.spot_view_index = app.num_filtered_spots;
                 end
            elseif strcmp(key,'s')
                
               image_title = strrep(app.main_axis.Title.String, ' ', '_');
               image_title = sprintf("%s.png", image_title);
               exportgraphics(app.main_axis, image_title);
            end
            
            app.LoadeddataLabel.Text = key;
            
            app.targetSlider.Value = app.spot_view_index;
            spot_data = app.adjusted_data(app.spot_rows{app.filtered_spot_indices(app.spot_view_index)}, :);
            app.displaySpotData(spot_data);
        end

        % Value changed function: minconsecutivepointsSpinner
        function minconsecutivepointsSpinnerValueChanged(app, event)
            value = app.minconsecutivepointsSpinner.Value;
            app.updateAllFields();
        end

        % Value changed function: showsmoothedCheckBox
        function showsmoothedCheckBoxValueChanged(app, event)
            value = app.showsmoothedCheckBox.Value;
            spot_data = app.adjusted_data(app.spot_rows{app.filtered_spot_indices(app.spot_view_index)}, :);
            app.displaySpotData(spot_data);
        end

        % Value changed function: channel_filter_list
        function channel_filter_listValueChanged(app, event)
            value = app.channel_filter_list.Value;
            
            app.channels_to_filter = cell2mat(value);
            app.updateAllFields();
        end

        % Value changed function: netfoldchangeSpinner
        function netfoldchangeSpinnerValueChanged(app, event)
            value = app.netfoldchangeSpinner.Value;
            app.updateAllFields();
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create SingleMoleculeDataBrowserUIFigure and hide until all components are created
            app.SingleMoleculeDataBrowserUIFigure = uifigure('Visible', 'off');
            app.SingleMoleculeDataBrowserUIFigure.Position = [100 100 823 679];
            app.SingleMoleculeDataBrowserUIFigure.Name = 'Single Molecule Data Browser';
            app.SingleMoleculeDataBrowserUIFigure.KeyPressFcn = createCallbackFcn(app, @SingleMoleculeDataBrowserUIFigureKeyPress, true);

            % Create main_axis
            app.main_axis = uiaxes(app.SingleMoleculeDataBrowserUIFigure);
            title(app.main_axis, 'Title')
            xlabel(app.main_axis, 'frame')
            ylabel(app.main_axis, 'intensity')
            app.main_axis.PlotBoxAspectRatio = [1.57909604519774 1 1];
            app.main_axis.YLim = [0 1];
            app.main_axis.ZLim = [0 1];
            app.main_axis.Position = [25 66 631 444];

            % Create loadsmfcsvfileButton
            app.loadsmfcsvfileButton = uibutton(app.SingleMoleculeDataBrowserUIFigure, 'push');
            app.loadsmfcsvfileButton.ButtonPushedFcn = createCallbackFcn(app, @loadsmfcsvfileButtonPushed, true);
            app.loadsmfcsvfileButton.FontWeight = 'bold';
            app.loadsmfcsvfileButton.Position = [22 644 108 23];
            app.loadsmfcsvfileButton.Text = 'load smf csv file';

            % Create filename_loaded_label
            app.filename_loaded_label = uilabel(app.SingleMoleculeDataBrowserUIFigure);
            app.filename_loaded_label.Position = [216 643 325 22];
            app.filename_loaded_label.Text = 'None...';

            % Create LoadeddataLabel
            app.LoadeddataLabel = uilabel(app.SingleMoleculeDataBrowserUIFigure);
            app.LoadeddataLabel.FontWeight = 'bold';
            app.LoadeddataLabel.Position = [139 644 80 22];
            app.LoadeddataLabel.Text = 'Loaded data:';

            % Create targetSliderLabel
            app.targetSliderLabel = uilabel(app.SingleMoleculeDataBrowserUIFigure);
            app.targetSliderLabel.HorizontalAlignment = 'right';
            app.targetSliderLabel.FontWeight = 'bold';
            app.targetSliderLabel.Position = [6 33 39 22];
            app.targetSliderLabel.Text = 'target';

            % Create targetSlider
            app.targetSlider = uislider(app.SingleMoleculeDataBrowserUIFigure);
            app.targetSlider.Limits = [1 2];
            app.targetSlider.ValueChangingFcn = createCallbackFcn(app, @targetSliderValueChanging, true);
            app.targetSlider.MinorTicks = [1 1.01 1.02 1.03 1.04 1.05 1.06 1.07 1.08 1.09 1.1 1.11 1.12 1.13 1.14 1.15 1.16 1.17 1.18 1.19 1.2 1.21 1.22 1.23 1.24 1.25 1.26 1.27 1.28 1.29 1.3 1.31 1.32 1.33 1.34 1.35 1.36 1.37 1.38 1.39 1.4 1.41 1.42 1.43 1.44 1.45 1.46 1.47 1.48 1.49 1.5 1.51 1.52 1.53 1.54 1.55 1.56 1.57 1.58 1.59 1.6 1.61 1.62 1.63 1.64 1.65 1.66 1.67 1.68 1.69 1.7 1.71 1.72 1.73 1.74 1.75 1.76 1.77 1.78 1.79 1.8 1.81 1.82 1.83 1.84 1.85 1.86 1.87 1.88 1.89 1.9 1.91 1.92 1.93 1.94 1.95 1.96 1.97 1.98 1.99 2];
            app.targetSlider.FontWeight = 'bold';
            app.targetSlider.Position = [66 42 574 3];
            app.targetSlider.Value = 1;

            % Create DataprocessorPanel
            app.DataprocessorPanel = uipanel(app.SingleMoleculeDataBrowserUIFigure);
            app.DataprocessorPanel.Title = 'Data processor';
            app.DataprocessorPanel.FontWeight = 'bold';
            app.DataprocessorPanel.Position = [25 577 631 57];

            % Create maxpxdisSpinnerLabel
            app.maxpxdisSpinnerLabel = uilabel(app.DataprocessorPanel);
            app.maxpxdisSpinnerLabel.HorizontalAlignment = 'right';
            app.maxpxdisSpinnerLabel.Position = [5 8 64 22];
            app.maxpxdisSpinnerLabel.Text = 'max px dis';

            % Create maxpxdisSpinner
            app.maxpxdisSpinner = uispinner(app.DataprocessorPanel);
            app.maxpxdisSpinner.Limits = [0 6];
            app.maxpxdisSpinner.ValueChangedFcn = createCallbackFcn(app, @maxpxdisSpinnerValueChanged, true);
            app.maxpxdisSpinner.Position = [73 8 49 22];

            % Create backgroundthresholdSpinnerLabel
            app.backgroundthresholdSpinnerLabel = uilabel(app.DataprocessorPanel);
            app.backgroundthresholdSpinnerLabel.HorizontalAlignment = 'right';
            app.backgroundthresholdSpinnerLabel.Position = [136 8 123 22];
            app.backgroundthresholdSpinnerLabel.Text = 'background threshold';

            % Create backgroundthresholdSpinner
            app.backgroundthresholdSpinner = uispinner(app.DataprocessorPanel);
            app.backgroundthresholdSpinner.Step = 0.1;
            app.backgroundthresholdSpinner.Limits = [0.2 4];
            app.backgroundthresholdSpinner.ValueChangedFcn = createCallbackFcn(app, @backgroundthresholdSpinnerValueChanged, true);
            app.backgroundthresholdSpinner.Position = [265 8 55 22];
            app.backgroundthresholdSpinner.Value = 1;

            % Create SpotfiltersPanel
            app.SpotfiltersPanel = uipanel(app.SingleMoleculeDataBrowserUIFigure);
            app.SpotfiltersPanel.Title = 'Spot filters';
            app.SpotfiltersPanel.FontWeight = 'bold';
            app.SpotfiltersPanel.Position = [25 521 631 57];

            % Create numstatesSpinnerLabel
            app.numstatesSpinnerLabel = uilabel(app.SpotfiltersPanel);
            app.numstatesSpinnerLabel.HorizontalAlignment = 'right';
            app.numstatesSpinnerLabel.Position = [330 8 68 22];
            app.numstatesSpinnerLabel.Text = 'num states ';

            % Create numstatesSpinner
            app.numstatesSpinner = uispinner(app.SpotfiltersPanel);
            app.numstatesSpinner.Limits = [-1 10];
            app.numstatesSpinner.ValueChangedFcn = createCallbackFcn(app, @numstatesSpinnerValueChanged, true);
            app.numstatesSpinner.Position = [398 8 49 22];
            app.numstatesSpinner.Value = -1;

            % Create minpointsSpinnerLabel
            app.minpointsSpinnerLabel = uilabel(app.SpotfiltersPanel);
            app.minpointsSpinnerLabel.HorizontalAlignment = 'right';
            app.minpointsSpinnerLabel.Position = [8 9 62 22];
            app.minpointsSpinnerLabel.Text = 'min points';

            % Create minpointsSpinner
            app.minpointsSpinner = uispinner(app.SpotfiltersPanel);
            app.minpointsSpinner.Limits = [0 30];
            app.minpointsSpinner.ValueChangedFcn = createCallbackFcn(app, @minpointsSpinnerValueChanged, true);
            app.minpointsSpinner.Position = [73 9 49 22];

            % Create minconsecutivepointsSpinnerLabel
            app.minconsecutivepointsSpinnerLabel = uilabel(app.SpotfiltersPanel);
            app.minconsecutivepointsSpinnerLabel.HorizontalAlignment = 'right';
            app.minconsecutivepointsSpinnerLabel.Position = [136 8 129 22];
            app.minconsecutivepointsSpinnerLabel.Text = 'min consecutive points';

            % Create minconsecutivepointsSpinner
            app.minconsecutivepointsSpinner = uispinner(app.SpotfiltersPanel);
            app.minconsecutivepointsSpinner.Limits = [0 30];
            app.minconsecutivepointsSpinner.ValueChangedFcn = createCallbackFcn(app, @minconsecutivepointsSpinnerValueChanged, true);
            app.minconsecutivepointsSpinner.Position = [268 8 49 22];

            % Create netfoldchangeSpinnerLabel
            app.netfoldchangeSpinnerLabel = uilabel(app.SpotfiltersPanel);
            app.netfoldchangeSpinnerLabel.HorizontalAlignment = 'right';
            app.netfoldchangeSpinnerLabel.Position = [481 6 90 23];
            app.netfoldchangeSpinnerLabel.Text = 'net fold change';

            % Create netfoldchangeSpinner
            app.netfoldchangeSpinner = uispinner(app.SpotfiltersPanel);
            app.netfoldchangeSpinner.Limits = [-1 10];
            app.netfoldchangeSpinner.ValueChangedFcn = createCallbackFcn(app, @netfoldchangeSpinnerValueChanged, true);
            app.netfoldchangeSpinner.Position = [572 7 49 22];
            app.netfoldchangeSpinner.Value = -1;

            % Create exportButton
            app.exportButton = uibutton(app.SingleMoleculeDataBrowserUIFigure, 'push');
            app.exportButton.FontWeight = 'bold';
            app.exportButton.Position = [687 33 100 23];
            app.exportButton.Text = 'export';

            % Create showsmoothedCheckBox
            app.showsmoothedCheckBox = uicheckbox(app.SingleMoleculeDataBrowserUIFigure);
            app.showsmoothedCheckBox.ValueChangedFcn = createCallbackFcn(app, @showsmoothedCheckBoxValueChanged, true);
            app.showsmoothedCheckBox.Text = 'show smoothed';
            app.showsmoothedCheckBox.Position = [540 54 108 22];

            % Create color_panel
            app.color_panel = uipanel(app.SingleMoleculeDataBrowserUIFigure);
            app.color_panel.Title = 'Channel colors';
            app.color_panel.Position = [668 121 149 360];

            % Create ApplyfilterstochannelsListBoxLabel
            app.ApplyfilterstochannelsListBoxLabel = uilabel(app.SingleMoleculeDataBrowserUIFigure);
            app.ApplyfilterstochannelsListBoxLabel.HorizontalAlignment = 'right';
            app.ApplyfilterstochannelsListBoxLabel.FontWeight = 'bold';
            app.ApplyfilterstochannelsListBoxLabel.Position = [665 644 143 23];
            app.ApplyfilterstochannelsListBoxLabel.Text = 'Apply filters to channels';

            % Create channel_filter_list
            app.channel_filter_list = uilistbox(app.SingleMoleculeDataBrowserUIFigure);
            app.channel_filter_list.Items = {};
            app.channel_filter_list.Multiselect = 'on';
            app.channel_filter_list.ValueChangedFcn = createCallbackFcn(app, @channel_filter_listValueChanged, true);
            app.channel_filter_list.Position = [668 503 149 131];
            app.channel_filter_list.Value = {};

            % Show the figure after all components are created
            app.SingleMoleculeDataBrowserUIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = sm_viewer2_exported

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.SingleMoleculeDataBrowserUIFigure)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.SingleMoleculeDataBrowserUIFigure)
        end
    end
end