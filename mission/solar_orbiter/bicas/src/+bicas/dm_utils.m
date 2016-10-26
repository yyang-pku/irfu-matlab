classdef dm_utils
% Collections of minor utility functions (in the form of static methods) used by data_manager.
% The functions are collected here to reduce the size of data_manager.
% dm_utils = data_manager utilities
%
% Author: Erik P G Johansson, IRF-U, Uppsala, Sweden
% First created 2016-10-10

%============================================================================================================
% PROPOSAL: Move some functions to "utils".
%   Ex: add_components_to_struct, select_subset_from_struct
% PROPOSAL: Write test code for ACQUISITION_TIME_to_tt2000 and inversion.
% PROPOSAL: Split up in separate files?!
% PROPOSAL: Reorg select_subset_from_struct into returning a list of intervals instead.
%
% PROPOSAL: More analogous names and functionality for all functions for converting N samples/record --> 1 sample/record.
%   Ex: reshape_to_1_sample_per_record
%   Ex: ACQUISITION_TIME___expand_to_sequences
%   Ex: tt2000___expand_to_sequences
%   NOTE: Time conversion may require moving the zero-point within the snapshot/record.
%   PROPOSAL: Names
%       convert_Nspr_to_1spr_samples
%       convert_Nspr_to_1spr_tt2000
%       convert_Nspr_to_1spr_ACQUISITION_TIME
%   PROPOSAL: All have N_seq as column vector.



    methods(Static, Access=public)

        function filtered_data = filter_rows(data, row_filter)
        % Function intended for filtering out (copying selectively) data from a zVariable.
        %
        % data          : Numeric array with N rows.             (Intended to represent zVariables with N records.)
        % row_filter    : Numeric/logical 1D vector with N rows. (Intended to represent zVariables with N records.)
        % filtered_data : Array of the same size as "records", with
        %                 filtered_data(i,:,:, ...) == records(i,:,:, ...), for record_filter(i)~=0.
        %                 filtered_data(i,:,:, ...) == NaN,                 for record_filter(i)==0.

            % Name? filter_rows? filter_records?
            
            % ASSERTIONS
            if ~iscolumn(row_filter)     % Not really necessary to require row vector, only 1D vector.
                error('BICAS:dm_utils:Assertion:IllegalArgument', 'row_filter is not a 1D vector.')  % Use "DatasetFormat"?
            elseif size(row_filter, 1) ~= size(data, 1)
                error('BICAS:dm_utils:Assertion:IllegalArgument', 'Numbers of records do not match.')    % Use "DatasetFormat"?
            elseif ~isfloat(data)
                error('BICAS:dm_utils:Assertion:IllegalArgument', 'data is not a floating-point class (can not represent NaN).')    % Use "DatasetFormat"?
            end
            
            
            
            % Copy all data
            filtered_data = data;
            
            % Overwrite data that should not have been copied with NaN
            % --------------------------------------------------------
            % IMPLEMENTATION NOTE: Command works empirically for filtered_data having any number of dimensions. However,
            % if row_filter and filtered_data have different numbers of rows, then the final array may get the wrong
            % dimensions (without triggering error!) since new array components (indices) are assigned. ==> The
            % corresponding ASSERTION is important!
            filtered_data(row_filter==0, :) = NaN;
        end



        function s = select_subset_from_struct(s, i_first, i_last)
        % Given a struct, select a subset of that struct defined by a range of column indicies for every field.
        % Generic utility function.
        
            fn_list = fieldnames(s);
            N = NaN;
            for i=1:length(fn_list)
                fn = fn_list{i};
                
                % ASSERTIONS
                if isnan(N)
                    N = size(s.(fn), 1);
                    if (N < i_first) || (N < i_last)
                        error('BICAS:dm_utils:Assertion', 'i_first or i_last outside of interval of indices (rows).')
                    end
                elseif N ~= size(s.(fn), 1)
                   error('BICAS:dm_utils:Assertion', 'Not all struct fields have the same number of rows.')
                end
                
                s.(fn) = s.(fn)(i_first:i_last, :, :);
            end
        end
        
        

        function s = add_components_to_struct(s, s_amendment)
        % Add values to every struct field by adding components after their highest row index (let them grow in
        % the row index).
        
        % PROPOSAL: Better name. ~rows, ~fields
        %   Ex: add_row_components_to_struct_fields
            
            % Generic utility function.
            fn_list = fieldnames(s_amendment);
            for i=1:length(fn_list)
                fn = fn_list{i};
                
                s.(fn) = [s.(fn) ; s_amendment.(fn)];
            end
        end



        function freq = get_LFR_frequency(FREQ)
        % Convert LFR zVariable FREQ constant values to Hz.
        %
        % FREQ : The FREQ zVariable in LFR CDFs.
        % freq : Frequency in Hz.
            
            global CONSTANTS
            
            % ASSERTION
            unique_values = unique(FREQ);
            if ~all(ismember(unique_values, [0,1,2,3]))
                unique_values_str = sprintf('%d', unique_values);   % NOTE: Has to print without \n to keep all values on a single-line string.
                error('BICAS:dm_utils:Assertion:IllegalArgument:DatasetFormat', 'Found unexpected values in LFR_FREQ (unique values: %s).', unique_values_str)
            end
            
            % NOTE: Implementation that works for arrays of any size.
            freq = ones(size(FREQ)) * -1;
            freq(FREQ==0) = CONSTANTS.C.LFR.F0;
            freq(FREQ==1) = CONSTANTS.C.LFR.F1;
            freq(FREQ==2) = CONSTANTS.C.LFR.F2;
            freq(FREQ==3) = CONSTANTS.C.LFR.F3;
        end
        
        
        
        function Rx = get_LFR_Rx(R0, R1, R2, FREQ)
        % Return the relevant value of LFR CDF zVariables R0, R1, or R2, or a hypothetical but analogous "R3" which is always 1.
        %
        % R0, R1, R2, FREQ : LFR CDF zVariables. All must have identical array sizes.
        % Rx               : Same size array as R0, R1, R2, FREQ. The relevant values are copied, respectively, from
        %                    R0, R1, R2, or an analogous hypothetical "R3" that is a constant (=1) depending on
        %                    the value of FREQ in the corresponding component.
        %
        % NOTE: Works for all array sizes.
            
            Rx = -ones(size(FREQ));        % Set to -1 (should always be overwritten).
            
            I = (FREQ==0); Rx(I) = R0(I);
            I = (FREQ==1); Rx(I) = R1(I);
            I = (FREQ==2); Rx(I) = R2(I);
            I = (FREQ==3); Rx(I) = 1;      % The value of a hypothetical (non-existant, constant) analogous zVariable "R3".
        end



        %=====================================================================================================================
        % Finds the greatest i_last such that all varargin{k}(i) are equal for i_first <= i <= i_last separately for every k.
        % Useful for finding a continuous sequence of records with the same data.
        %
        % ASSUMES: varargin{i} are all column arrays of the same size.
        %=====================================================================================================================
        function i_last = find_last_same_sequence(i_first, varargin)
            % PROPOSAL: Better name?
            
            % ASSERTIONS
            if 0 == length(varargin)
                error('BICAS:dm_utils:Assertion:IllegalArgument', 'There is no vectors to look for sequences in.')
            end
            for k = 1:length(varargin)
                if ~iscolumn(varargin{k})
                    error('BICAS:dm_utils:Assertion:IllegalArgument', 'varargins are not all column vectors.')
                end
            end                
            N_records = size(varargin{1}, 1);
            if N_records == 0
                error('BICAS:dm_utils:Assertion:IllegalArgument', 'Vectors are empty.')
            end
                
                
            i_last = i_first;
            while i_last+1 <= N_records       % For as long as there is another row...
                for k = 1:length(varargin)
                    %if varargin{k}(i_first) ~= varargin{k}(i_last+1)
                    if ~isequaln(varargin{k}(i_first), varargin{k}(i_last+1))
                        % CASE: This row is different from the previous one.
                        return
                    end
                end
                i_last = i_last + 1;
            end
            i_last = N_records;
        end



        function t_tt2000 = ACQUISITION_TIME_to_tt2000(ACQUISITION_TIME)
            % Convert time in from ACQUISITION_TIME to tt2000 which is used for Epoch in CDF files.
            % 
            % NOTE: t_tt2000 is in int64.
            % NOTE: ACQUSITION_TIME can not be negative since it is uint32.
            
            global CONSTANTS
            
            bicas.dm_utils.assert_ACQUISITION_TIME(ACQUISITION_TIME)
            
            ACQUISITION_TIME = double(ACQUISITION_TIME);
            t_AT = ACQUISITION_TIME(:, 1) + ACQUISITION_TIME(:, 2) / 65536;
            t_tt2000 = spdfcomputett2000(CONSTANTS.C.ACQUISITION_TIME_EPOCH_UTC) + int64(t_AT * 1e9);   % NOTE: spdfcomputett2000 returns int64 (as it should).
        end
        
        
        
        function ACQUISITION_TIME = tt2000_to_ACQUISITION_TIME(t_tt2000)
        % Convert from tt2000 to ACQUISITION_TIME.
        %
        % t_tt2000 : Nx1 vector. Not required to be int64.
        %       NOTE: The real Epoch is int64.
        % ACQUISITION_TIME : Nx2 vector. uint32.
        %       NOTE: ACQUSITION_TIME can not be negative since it is uint32.
        
            % QUESTION: Should this function require tt2000 argument to be uint32?
            
            global CONSTANTS
            
            % ASSERTIONS
            bicas.dm_utils.assert_Epoch(t_tt2000)

            % NOTE: Important to type cast to double because of multiplication
            t_AT = double(int64(t_tt2000) - spdfcomputett2000(CONSTANTS.C.ACQUISITION_TIME_EPOCH_UTC)) * 1e-9;
            
            % ASSERTION: ACQUISITION_TIME must not be negative.
            if any(t_AT < 0)
                error('BICAS:dm_manager:Assertion:IllegalArgument:DatasetFormat', 'Can not produce ACQUISITION_TIME (uint32) with negative number of integer seconds.')
            end
            
            t_AT = round(t_AT*65536) / 65536;
            t_AT_floor = floor(t_AT);
            
            ACQUISITION_TIME = uint32([]);
            ACQUISITION_TIME(:, 1) = uint32(t_AT_floor);
            ACQUISITION_TIME(:, 2) = uint32((t_AT - t_AT_floor) * 65536); % Should not be able to produce 65536 since t_AT already rounded (to parts of 2^-16).
        end
        
        
        
        function UTC_str = tt2000_to_UTC_str(t_tt2000)
            % Convert tt2000 value to UTC string with nanoseconds.
            %
            % Example: 2016-04-16T02:26:14.196334848
            % NOTE: This is the inverse to spdfparsett2000.
            
            bicas.dm_utils.assert_Epoch(t_tt2000)
            
            v = spdfbreakdowntt2000(t_tt2000);
            UTC_str = sprintf('%04i-%02i-%02iT%02i:%02i:%2i.%03i%03i%03i', v(1), v(2), v(3), v(4), v(5), v(6), v(7), v(8), v(9));
        end
        
        
        
        function data_2 = reshape_to_1_sample_per_record(data_1)
        % Convert data from N samples/record to 1 sample/record (from a matrix to a column vector).
        
            % NOTE: ndims always returns at least two, which is exactly what we want, also for empty and scalars, and row vectors.
            if ndims(data_1) > 2
                error('BICAS:dm_utils:Assertion:IllegalArgument', 'data_1 has more than two dimensions.')
            end
            
            data_2 = reshape(data_1', numel(data_1), 1);
        end
        
        
        
        function t_tt2000_2 = tt2000___expand_to_sequences( t_tt2000_1, N_sequence, F_sequence )
        % t_tt2000_1 : Nx1 vector.
        % t_tt2000_2 : Nx1 vector. Like t_tt2000_1 but each single time (row) has been replaced by a constantly
        %              incrementing sequence of times (rows). Every such sequence begins with the original
        %              value, has length N_samples_per_record with frequency F_records(i).
        %              NOTE: There is no check that the entire sequence is monotonic. LFR data can have snapshots that
        %              overlap in time!
        % N_sequence : Positive integer. Scalar. Number of values per sequence.
        % F_records  : Nx1 vector. Frequency of samples within a subsequence (CDF record). Unit: Hz.
            
            % PROPOSAL: Turn into more generic function, working on number sequences in general.
            % PROPOSAL: N_sequence should be a column vector.
            %    NOTE: TDS-LFM-RSWF, LFR-SURV-CWF has varying snapshot length.
            %    PRO: Could be useful for converting N samples/record to sample/record for calibration with transfer functions.
            %       NOTE: Then also needs function that does the reverse.
            
            % ASSERTION:
            bicas.dm_utils.assert_Epoch(t_tt2000_1)
            if numel(N_sequence) ~= 1
                error('BICAS:dm_utils:Assertion:IllegalArgument', 'N_sequence not scalar.')
            elseif size(F_sequence, 1) ~= size(t_tt2000_1, 1)
                error('BICAS:dm_utils:Assertion:IllegalArgument', 'F_sequence and t_tt2000 do not have the same number of rows.')
            end
            
            N_records = numel(t_tt2000_1);
            
            % Express frequency as period length in ns (since tt2000 uses ns as a unit).
            % Use the same MATLAB class as tt
            T_sequence = int64(1e9 ./ F_sequence);   
                        
            % Conventions:
            % ------------
            % Variable names
            %    One letter  : vector (row/column)
            %    Two letters : matrix
            % Time unit: ns (as for tt2000)            
            % Algorithm should require integers to have a very predictable behaviour (useful when testing).
            
            % One unique time per record.
            t_records  = t_tt2000_1;  % Column vector            
            tt_records = repmat(t_records, [1, N_sequence]);
            
            % Incrementing indices for every sample (within record).
            i_samples  = int64(0:(N_sequence-1));
            ii_samples = repmat(i_samples, [N_records, 1]);
            
            % Unique frequency per record.
            TT_record = repmat(T_sequence, [1, N_sequence]);
            
            % Unique time for every sample in every record.
            tt = tt_records + ii_samples .* TT_record;
            
            % Convert to 2D matrix --> 1D column vector.
            t_tt2000_2 = reshape(tt', [N_records*N_sequence, 1]);
        end
        
        
        
        function ACQUISITION_TIME_2 = ACQUISITION_TIME___expand_to_sequences(  ACQUISITION_TIME_1, N_sequence, F_sequence  )
        % Function intended for converting ACQUISITION_TIME (always one time per record) from many samples/record to one sample/record.
        % Analogous to tt2000___expand_to_sequences.
        % 
        % ACQUISITION_TIME_1 : Nx2 vector.
        % ACQUISITION_TIME_2 : Nx2 vector.

            % PROPOSAL: Better function name.
            %    ACQUISITION_TIME___replace_with_sequence
            %    ACQUISITION_TIME___substitute_with_sequences
            %    ACQUISITION_TIME___expand
            %    ACQUISITION_TIME___expand_to_sequences
            %    ACQUISITION_TIME___convert_to_sample_per_record

            % Command-line algorithm "test code":
            % clear; t_rec = [1;2;3;4]; f = [5;1;5;20]; N=length(t_rec); M=5; I_sample=repmat(0:(M-1), [N, 1]); F=repmat(f, [1,M]); T_rec = repmat(t_rec, [1,M]); T = T_rec + I_sample./F; reshape(T', [numel(T), 1])
            
            % ASSERTIONS
            bicas.dm_utils.assert_ACQUISITION_TIME(ACQUISITION_TIME_1)

            t_tt2000_1 = bicas.dm_utils.ACQUISITION_TIME_to_tt2000(ACQUISITION_TIME_1);
            t_tt2000_2 = bicas.dm_utils.tt2000___expand_to_sequences(t_tt2000_1, N_sequence, F_sequence);
            ACQUISITION_TIME_2 = bicas.dm_utils.tt2000_to_ACQUISITION_TIME(t_tt2000_2);
        end


        
%         function data_dest = nearest_interpolate_records(ACQUISITION_TIME_src, data_src, ACQUISITION_TIME_dest)
%             % Take CDF data (src) divided into records (points in time) and use that to produce data
%             % divided into other records (other points in time).
%             %
%             % Will produce NaN for values of ACQUISITION_TIME_dest outside the range of
%             % ACQUISITION_TIME_src.
%             %
%             % ASSUMES: data_src is a column vector (i.e. one scalar/record).
%             %
%             % NOTE: Returned data is double (i.e. not e.g. logical).
%         
%             % PROPOSAL: Better name?
%             % PROPOSAL: Type cast return variable?
%             % PROPOSAL: ABOLISH? Should not use functions which are tied to a specific time format (ACQUSITION_TIME vs
%             % Epoch)
%             
%             t_src  = bicas.dm_utils.ACQUISITION_TIME_to_linear_seconds(ACQUISITION_TIME_src);
%             t_dest = bicas.dm_utils.ACQUISITION_TIME_to_linear_seconds(ACQUISITION_TIME_dest);
% 
%             % "Vq = interp1(X,V,Xq,METHOD,EXTRAPVAL) replaces the values outside of the
%             % interval spanned by X with EXTRAPVAL.  NaN and 0 are often used for
%             % EXTRAPVAL."
%             % "'linear'   - (default) linear interpolation"
%             data_dest = interp1(t_src, double(data_src), t_dest, 'nearest', NaN);
%         end



        % MOVE TO +utils?
        function unique_values = unique_NaN(A)
            % Return number of unique values in array, treating +Inf, -Inf, and NaN as equal to themselves.
            % (MATLAB's "unique" function does not do this for NaN.)
            %
            % NOTE: Should work for all dimensionalities.
        
            % NOTE: "unique" has special behaviour whic hmust be taken into account:
            % 1) Inf and -Inf are treated as equal to themselves.
            % 2) NaN is treated as if it is NOT equal itself. ==> Can thus return multiple instances of NaN.
            % 3) "unique" always puts NaN at the then of the vector of unique values (one or many NaN).
            unique_values = unique(A);
            
            % Remove all NaN unless it is found in the last component (save one legitimate occurrence of NaN, if there is any).
            % NOTE: Does work for empty matrices.
            unique_values(isnan(unique_values(1:end-1))) = [];
        end
        
        
        
        function log_unique_values_summary(variable_name, v)
        % Log number of unique values, and NaN, found in numeric matrix.
        % Useful for summarizin dataset data (usually many unique values).            
        %
        % NOTE: Can handle zero values.
        
            % Excplicitly state including/excluding NaN? Number of NaN? Percent NaN? Min-max?
            
            N_values = length(bicas.dm_utils.unique_NaN(v));
            N_NaN = sum(isnan(v(:)));
            irf.log('n', sprintf('Number of unique %-6s values: %5d (%3i%%=%6i/%6i NaN)', ...
                variable_name, N_values, ...
                (N_NaN/numel(v))*100, ...
                N_NaN, numel(v)))
        end

        
        
        function log_unique_values_all(variable_name, v)
        % Log all unique values found in numeric matrix.
        % Useful for logging dataset settings (few unique values).            
        %
        % NOTE: Can handle zero values.
            
            % Automatically switch to log_unique_values_summary if too many?
            % Print number of NaN?
            %N_NaN = sum(isnan(v(:)));
            values_str = sprintf('%d ', bicas.dm_utils.unique_NaN(v));
            irf.log('n', sprintf('Unique %s values: %s', variable_name, values_str))
        end
        
        
        
        function log_tt2000_interval(variable_name, t)
            % NOTE: Assumes that t is sorted in time, increasing.
            if ~isempty(t)
                str_first = bicas.dm_utils.tt2000_to_UTC_str(t(1));
                str_last  = bicas.dm_utils.tt2000_to_UTC_str(t(end));
                irf.log('n', sprintf('%s: %s -- %s', variable_name, str_first, str_last))
            else
                irf.log('n', sprintf('%s: <empty>', variable_name))
            end
        end
        
        
        
        function assert_Epoch(Epoch)
        % Check that variable is an "Epoch-like" variable.
        
        % NOTE: Checks for column vector.
        % QUESTION: Good name? "tt2000"?
            if ~iscolumn(Epoch)
                error('BICAS:dm_utils:Assertion:IllegalArgument', 'Argument is not a column vector')   % Right ID?                
            elseif ~isa(Epoch, 'int64')
                error('BICAS:dm_utils:Assertion:IllegalArgument', 'Argument has the wrong class.')   % Right ID?
            end
        end

        
        
        function assert_ACQUISITION_TIME(ACQUISITION_TIME)
            if ~isa(ACQUISITION_TIME, 'uint32')
                error('BICAS:dm_utils:Assertion:IllegalArgument', 'ACQUISITION_TIME is not uint32.')
            elseif ndims(ACQUISITION_TIME) ~= 2
                error('BICAS:dm_utils:Assertion:IllegalArgument', 'ACQUISITION_TIME is not two-dimensional.')
            elseif size(ACQUISITION_TIME, 2) ~= 2
                error('BICAS:dm_utils:Assertion:IllegalArgument', 'ACQUISITION_TIME is does not have two columns.')
            elseif any(ACQUISITION_TIME(:, 2) < 0 | 65536 <= ACQUISITION_TIME(:, 2))   % NOTE: Permits up to 65526- to make it possible to use fractions (non-integers).
                error('BICAS:dm_utils:Assertion:IllegalArgument', 'ACQUISITION_TIME has illegal negative subseconds.')
            elseif any(ACQUISITION_TIME(:, 1) < 0)
                error('BICAS:dm_utils:Assertion:IllegalArgument', 'ACQUISITION_TIME has negative number of integer seconds.')
            end
        end
        
        
        
        function assert_unvaried_N_rows(s)
        % Assert that all numeric fields in a structure have the same number of rows.
        %
        % Useful since in data_manager, much code assumes that struct fields represent CDF zVar records.
            
            % PROPOSAL: Better name.
            %   Ex: _equal_rows, _equal_N_rows, _same_N_rows, _equal_nbr_of_rows
            
            fn_list = fieldnames(s);
            N_rows = [];
            for i = 1:length(fn_list)
                fn = fn_list{i};
                
                if isnumeric(s.(fn))
                    N_rows(end+1) = size(s.(fn), 1);
                end
            end
            if length(unique(N_rows)) > 1    % NOTE: length=0 valid for struct containing zero numeric fields.
                error('BICAS:dm_utils:Assertion', 'Numeric fields in struct do not have the same number of rows (likely corresponding to CDF zVar records).')
            end
        end
        
    end   % Static
    
    
    
end

