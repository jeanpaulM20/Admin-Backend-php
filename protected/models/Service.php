<?php
Yii::import('application.extensions.conditions.*', true);
/**
 * This is the model class for table "{{services}}".
 *
 * The followings are the available columns in table '{{services}}':
 * @property integer $id
 * @property string $model
 * @property string $description
 * @property string $service_alias
 * @property string $service_params
 * @property string $select_fields
 * @property string $condition
 * @property string $order
 */
class Service extends CActiveRecord
{
	protected $_relationsToAdd = array();
	
	/**
	 * Returns the static model of the specified AR class.
	 * @param string $className active record class name.
	 * @return Services the static model class
	 */
	public static function model($className=__CLASS__)
	{
		return parent::model($className);
	}

	/**
	 * @return string the associated database table name
	 */
	public function tableName()
	{
		return '{{service}}';
	}

	/**
	 * @return array validation rules for model attributes.
	 */
	public function rules()
	{
		// NOTE: you should only define rules for those attributes that
		// will receive user inputs.
		return array(
			array('model, service_alias, title', 'required'),
			array('model, service_alias', 'length', 'max'=>255),
			array('service_params, select_fields, condition, order, title, description, group, publish, sortOrder', 'safe'),
			// The following rule is used by search().
			// Please remove those attributes that should not be searched.
			array('id, model, service_alias, service_params, select_fields, condition, title, order, description, group, publish, sortOrder', 'safe', 'on'=>'search'),
		);
	}

	/**
	 * @return array relational rules.
	 */
	public function relations()
	{
		// NOTE: you may need to adjust the relation name and the related
		// class name for the relations automatically generated below.
		return array(
		);
	}
	
	public function scopes()
    {
        return array(
            'published'=>array(
                'condition'=>'publish=1',
				'order' => 'sortOrder'
            )
		);
	}

	/**
	 * @return array customized attribute labels (name=>label)
	 */
	public function attributeLabels()
	{
		return array(
			'id' => 'ID',
			'model' => 'Model',
			'service_alias' => 'Service Alias',
			'service_params' => 'Service Params',
			'select_fields' => 'Select Fields',
			'condition' => 'Condition',
			'order' => 'Order',
			'description' => 'Description'
		);
	}

	/**
	 * Retrieves a list of models based on the current search/filter conditions.
	 * @return CActiveDataProvider the data provider that can return the models based on the search/filter conditions.
	 */
	public function search()
	{
		// Warning: Please modify the following code to remove attributes that
		// should not be searched.

		$criteria=new CDbCriteria;

		$criteria->compare('id',$this->id);
		$criteria->compare('model',$this->model,true);
		$criteria->compare('description',$this->model,true);
		$criteria->compare('service_alias',$this->service_alias,true);
		$criteria->compare('service_params',$this->service_params,true);
		$criteria->compare('select_fields',$this->select_fields,true);
		$criteria->compare('condition',$this->condition,true);
		$criteria->compare('order',$this->order,true);
		$criteria->compare('title',$this->title,true);
		$criteria->compare('group',$this->group,true);
		$criteria->compare('publish',$this->publish);
		$criteria->compare('sortOrder',$this->sortOrder);

		return new CActiveDataProvider($this, array(
			'criteria'=>$criteria,
		));
	}
	
	public function getParamArray() {
		if ($this->service_params) {
			$params = preg_split("/(\\r)+\\n/m", $this->service_params);
			$result = array();
			foreach($params as $one) {
				$result[$one] = true;
			}
			$result['limit'] = false;
			$result['page'] = false;
			return $result;
		} else {
			return array();
		}
	}
	
	protected function _getDbCriterion($params = array()) {
		$criteria = new CDbCriteria;
		
		if (isset($params['limit']) && (int)$params['limit']) {
			$criteria->limit = (int)$params['limit'];
			if (isset($params['page']) && (int)$params['page']) {
				$criteria->offset = $criteria->limit * ((int)$params['page'] - 1);
			}
		}
		unset($params['limit']);
		unset($params['page']);
		foreach ($params as $key => $param) {
			$criteria->params[':' . $key] = $param;
		}
		
		if ($this->order) {
			$orders = preg_split("/(\\r)+\\n/m", $this->order);
			foreach ($orders as $order) {
				$model = Helper::getModel($this->model);
				$modelName = $this->model;
				$order = trim($order);
				$matches = array();
				if (preg_match('/(.*?) (asc|desc)$/i', $order, $matches)) {
					$order = $matches[1];
					$dir = $matches[2];
				} else {
					$dir = 'asc';
				}
				$list = explode('.', $order);
				$field = array_pop($list);
				foreach ($list as $one) {
					$relations = $model->relations();
					if (isset($relations[$one])) {
						$model = new $relations[$one][1]();
						$modelName = $one;
						$criteria->with[] = $one;
					} else {
						throw new ParserException('Model ' . $modelName . ' does not have relation ' . $this->_name);
					}
				}
				if (!$model->hasAttribute($field)) {
					throw new ParserException('Model ' . $modelName . ' does not have attribute ' . $field);
				}
				if ($modelName == $this->model) {
					if (!$criteria->order) {
						$criteria->order = 't.' . $field . ' ' . $dir;
					} else {
						$criteria->order .= ', t.' . $field . ' ' . $dir;
					}
				} else {
					if (!$criteria->order) {
						$criteria->order = $modelName . '.' . $field . ' ' . $dir;
					} else {
						$criteria->order .= ', ' . $modelName . '.' . $field  . ' ' . $dir;
					}
				}
			}
		}
		
		return $criteria;
	}
	
	public function getData($params = array()) {
		
		$model = Helper::getModel($this->model);
		
		$criteria = Parser::parse($this->model, $this->condition);
		$criteria->mergeWith($this->_getDbCriterion($params));
		$rows = $model->findAll($criteria);
		$result = array();
		if (count($rows) > 0) {
			$select = preg_split("/(\\r)+\\n/m", $this->select_fields);
			foreach ($rows as $row) {
				$obj = new stdClass();
				foreach ($select as $sel) {
					$obj = $this->fillData($obj, $row, $sel);
				}
				$result[] = $obj;
			}
		}
		return $result;
	}
	
	protected function fillData($obj, $row, $field) {
		$list = explode('.', $field);
		$field = array_pop($list);
		if (count($list) > 0) {
			$table = array_shift($list);
			$child = $row->{$table};
			if ($row) {
				if (is_array($child)) {
					if (!$obj->{$table}) {
						$obj->{$table} = array();
					}
					foreach ($child as $one) {
						$obj->{$table}[$one->getPrimaryKey()] = $this->fillData(isset($obj->{$table}[$one->getPrimaryKey()]) ? $obj->{$table}[$one->getPrimaryKey()] : new stdClass(), $one, (count($list) > 0 ? implode('.', $list) . '.' . $field : $field ));
					}
					//$obj->{$table} = array_merge($obj->{$table});
				} else {
					$obj->{$table} = $this->fillData($obj->{$table} ? $obj->{$table} : new stdClass, $child, (count($list) > 0 ? implode('.', $list) . '.' . $field : $field ));
				}
			} else {
				$obj->{$table} = new stdClass;
			}
		} else {
			if ($field == '*') {
				if ($row) {
					foreach ($row->getAttributesWithLocalisation() as $attr => $value) {
						if (method_exists($row, 'get' . ucfirst($attr))) {
							$name = 'get' . ucfirst($attr);
							$obj->{$attr} = $row->$name();
						} else {
							$obj->{$attr} = $value;
						}
					}
				}
			} else {
				if ($row) {
					$localizable = $row->getLocalizableAttributes();
					if (in_array($field, $localizable)) {
						$vals = $row->addLocaleToArray(array(), $field, $row->{$field});
						foreach ($vals as $k => $v) {
							$obj->{$k} = $v;
						}
					} 
					if (method_exists($row, 'get' . ucfirst($field))) {
						$name = 'get' . ucfirst($field);
						$obj->{$field} = $row->$name();
					} elseif(substr($field, -4) == '_key') {
						$obj->{$field} = $row->{str_replace('_key', '', $field)};
					} else {
						$obj->{$field} = $row->{$field};
					}	
				}
			}
		}
		return $obj;
	}
	
	public function forModel($model)
	{
		$this->getDbCriteria()->addColumnCondition(array('model' => $model));
		return $this;
	}
}