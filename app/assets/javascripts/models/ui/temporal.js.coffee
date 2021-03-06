ns = @edsc.models.ui

ns.Temporal = do (ko,
                  config=@edsc.config,
                  dateUtil=@edsc.util.date,
                  stringUtil = @edsc.util.string,
                  KnockoutModel=@edsc.models.KnockoutModel) ->

  current_year = new Date().getUTCFullYear()

  class TemporalDate extends KnockoutModel
    constructor: (@defaultYear, @isRecurring) ->
      @date = ko.observable(null)
      @_invalidDateString = ko.observable(null)

      @_year = ko.observable(@defaultYear)
      @year = @computed
        read: =>
          date = @date()
          date?.getUTCFullYear() ? @_year()
        write: (year) =>
          year ?= @defaultYear
          date = @date.peek()
          if date?
            date = new Date(date.getTime())
            date.setUTCFullYear(year)
            @date(date)
          @_year(year)

      @humanDateString = @computed
        read: =>
          if @date()?
            dateStr = dateUtil.isoUtcDateTimeString(@date())
            dateStr = dateStr.substring(5) if @isRecurring()
            dateStr
          else
            @_invalidDateString() ? ""
        write: (dateStr) =>
          if dateStr?.length > 0
            dateStr = "#{@year()}-#{dateStr}" if @isRecurring()
            date = dateUtil.parseIsoUtcString(dateStr)
            if isNaN(date.getTime())
              @date(null)
              dateStr = dateStr.substring(5) if @isRecurring()
              @_invalidDateString(dateStr)
            else
              @date(date)
              @_invalidDateString(null)
          else
            @date(null)
            @_invalidDateString(null)

      @dayOfYearString = @computed
        read: =>
          date = @date()
          if date?
            "#{date.getUTCFullYear()}-#{stringUtil.padLeft(@dayOfYear(), '0', 3)}"
          else
            ""

        write: (dayStr) =>
          match = /(\d{4})-(\d{3})/.exec(dayStr)
          unless match
            @date(null)
            return
          year = parseInt(match[1], 10)
          day = parseInt(match[2], 10)
          date = new Date(Date.UTC(year, 0, day))
          unless date.getUTCFullYear() is year # Date is higher than the number of days in the year
            @date(null)
            return
          @date(date)

      @dayOfYear = @computed =>
        date = @date()
        if date?
          one_day = 1000 * 60 * 60 * 24
          year = 2007 # Sunday is January 1st, not a leap year
          #year = 2012 # Sunday is January 1st, leap year
          start_day = Date.UTC(year, 0, 0)
          end_day = Date.UTC(year, date.getUTCMonth(), date.getUTCDate())
          result = Math.floor((end_day - start_day) / one_day)
          result
        else
          null

      @queryDateString = @computed
        read: =>
          if @date() && @date().toString() != 'Invalid Date'
            dateUtil.toISOString(@date())
          else
            null
        write: (val) =>
          if !!val
            date = new Date(val)
          else
            date = null
            @year(@defaultYear)
          @date(date)

  class TemporalCondition extends KnockoutModel
    constructor: ->
      @isRecurring = ko.observable(false)
      @start = @disposable(new TemporalDate(1960, @isRecurring))
      @stop = @disposable(new TemporalDate(current_year, @isRecurring))

      @queryCondition = @computed(@_computeQueryCondition())
      @ranges = @computed(@_computeRanges, this, deferEvaluation: true)
      @isSet = @computed(@_computeIsSet, this, deferEvaluation: true)

      @years = @computed(@_computeYears())
      @yearsString = @computed =>
        @years().join(' - ')

    fromJson: (jsonObj) ->
      @queryCondition(jsonObj)

    serialize: ->
      @queryCondition()

    clear: =>
      @queryCondition(null)

    copy: (other) ->
      @queryCondition(other.queryCondition())

    intersect: (start, stop) ->
      ranges = @ranges()
      # No temporal means from the beginning of time to the end of time
      return [start, stop] if ranges.length == 0
      for [rangeStart, rangeStop] in ranges
        intersectStart = Math.max(start, rangeStart)
        intersectStop = Math.min(stop, rangeStop)
        return [new Date(intersectStart), new Date(intersectStop)] if intersectStart < intersectStop
      return null

    _computeIsSet: ->
      @start.date()? || @stop.date()?

    _computeRanges: ->
      {start, stop} = this
      result = []
      return result unless @isSet()

      if @isRecurring()
        if start.date() && stop.date()
          one_day = 1000 * 60 * 60 * 24
          year = 2007 # Sunday is January 1st, not a leap year
          #year = 2012 # Sunday is January 1st, leap year
          start_in_year = new Date(start.date())
          start_in_year.setUTCFullYear(year)
          start_offset = start_in_year - Date.UTC(year, 0, 0)

          stop_in_year = new Date(stop.date())
          stop_in_year.setUTCFullYear(year)
          stop_offset = stop_in_year - Date.UTC(year, 0, 0)

          for year in [start.year()..stop.year()]
            year_start = Date.UTC(year, 0, 0)
            result.push [year_start + start_offset, year_start + stop_offset]
      else
        start_date = start.date() ? new Date(Date.UTC(1970, 0, 0))
        stop_date = stop.date() ? new Date(config.present())
        result.push [start_date, stop_date]

      result

    _computeYears: ->
      read: =>
        if @isRecurring()
          [@start.year(), @stop.year()]
        else
          []
      write: (values) =>
        @start.year(values[0])
        @stop.year(values[1])

    _computeQueryCondition: ->
      read: =>
        start = @start
        stop = @stop

        return null unless start.date()? || stop.date()?

        result = [start.queryDateString(), stop.queryDateString()]

        result = result.concat(start.dayOfYear(), stop.dayOfYear()) if @isRecurring()

        result.join(',')

      write: (value) =>
        if value?
          [start, stop, startDay, stopDay]  = value.split(',')
          @isRecurring(startDay?)
        else
          @start.humanDateString(null)
          @stop.humanDateString(null)
        @start.queryDateString(start)
        @stop.queryDateString(stop)

  class Temporal extends KnockoutModel
    constructor: ->
      @applied = applied = @disposable(new TemporalCondition())
      @pending = pending = @disposable(new TemporalCondition())

      # Clear temporal when switching types
      pending.isRecurring.subscribe @disposable(=> pending.clear())

      # Copy applied to pending on change
      applied.queryCondition.subscribe @disposable((val) => pending.queryCondition(val))

    apply: =>
      @applied.copy(@pending)

  exports = Temporal
