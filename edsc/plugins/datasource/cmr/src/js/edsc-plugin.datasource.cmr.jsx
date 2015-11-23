let GranuleQuery = window.edsc.models.data.query.GranuleQuery,
    Granules = window.edsc.models.data.Granules,
    ajax = window.edsc.util.xhr.ajax;

export default class CmrDatasourcePlugin {

  // Required methods

  constructor(edsc, collection) {
    this._edsc = edsc;
    this._collection = collection;
    this._query = null;
    Object.defineProperty(collection, 'cmrGranuleQuery', {get: () => {return this.cmrQuery();}});
    Object.defineProperty(collection, 'cmrGranulesModel', {get: () => {return this.cmrData();}});
  }
  destroy(edsc) {
    this._edsc = null;
    this._collection = null;
    if (this._query) {
      this._query.dispose();
    }
    if (this._granules) {
      this._granules.dispose();
    }
  }
  toBookmarkParams() {
    this.cmrQuery().serialize();
  }
  fromBookmarkParams(json, fullQuery) {
    let query = this.cmrQuery();
    query.fromJson(json);
    if (fullQuery && fullQuery.sgd) {
      query.singleGranuleId(fullQuery.sgd);
    }
  }
  toQueryParams() {
    let query = this.cmrQuery(),
        params = query.params(),
        singleGranuleId = query.singleGranuleId();
    if (singleGranuleId) {
      params.echo_granule_id = singleGranuleId;
    }
    return params;
  }
  loadAccessOptions(callback, retry) {
    ajax({
      dataType: 'json',
      url: '/data/options',
      data: this.toQueryParams(),
      method: 'post',
      retry: retry,
      success: callback
    });
  }
  hasQueryConfig() {
    return this._query !== null && Object.keys(this._query.serialize()).length > 0;
  }
  updateFromCollectionData(collectionData) {
    let attributes = collectionData.searchable_attributes;
    if (attributes && this._query) {
      this._query.attributes.definitions(attributes);
    }
  }
  // Suggested methods

  // Implement only if row-specific temporal is supported
  setTemporal(values) {
    let temporal = this.temporal(),
        start = temporal.start,
        end = temporal.stop;
    if (temporal) {
      if (values.hasOwnProperty('recurring')) {
        temporal.isRecurring(values.recurring);
      }
      if (values.startDate) {
        start.date(values.startDate);
      }
      if (values.endDate) {
        end.date(values.endDate);
      }
      if (values.startYear) {
        start.date(values.startYear);
      }
      if (values.endYear) {
        end.date(values.endYear);
      }
    }
  }
  getTemporal() {
    let temporal = this.temporal();
    if (temporal) {
      return {
        startDate: temporal.start.date(),
        endDate: temporal.stop.date(),
        starYear: temporal.start.year(),
        endYear: temporal.stop.year(),
        recurring: temporal.isRecurring()
      };
    }
    return null;
  }

  temporal() {
    // TODO: Better story for row-specific temporal
    return this.cmrQuery().temporal.applied;
  }
  granuleDescription() {
    let hits = this._collection.granuleCount(),
        result;
    result = `${hits} Granule`;
    if (hits != 1) {
      result += 's';
    }
    return result;
  }

  // Other methods

  cmrQuery() {
    if (!this._query) {
      let collection = this._collection;
      this._query = new GranuleQuery(collection.id, collection.query, collection.searchable_attributes);
    }
    return this._query;
  }
  cmrData() {
    if (!this._granules) {
      this._granules = new Granules(this.cmrQuery(), this.cmrQuery().parentQuery);
    }
    return this._granules;
  }
};

edscplugin.loaded('datasource.cmr', CmrDatasourcePlugin);