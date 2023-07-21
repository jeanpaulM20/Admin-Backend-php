<?php

class ApiOperationFactory {
	
	public static function getListOperation($model) {
		$op = new stdClass();
		$op->path = "/" . $model;
		$op->description = 'Operations about ' . $model;
		$op->operations = array();
		
		$list = new stdClass();
		$list->httpMethod = 'GET';
		$list->summary = 'List all ' . $model . 's';
		$list->nickname = 'getAll' . ucfirst($model) . 's';
		
		$op->operations[] = $list;
		return $op;
	}
	
	public static function getViewOperation($model) {
		$op = new stdClass();
		$op->path = "/" . $model . '/{id}';
		$op->description = 'Operations about ' . $model;
		$op->operations = array();
		
		$list = new stdClass();
		$list->httpMethod = 'GET';
		$list->summary = 'View a ' . $model;
		$list->nickname = 'get' . ucfirst($model) .'ById';
		
		
		$id = new stdClass();
		$id->name = 'id';
		$id->description = 'ID of ' . $model . ' that needs to be fetched';
		$id->dataType = 'integer';
		$id->required = true;
		$id->allowMultiple = false;
		$id->paramType = 'path';
		
		$list->parameters = array($id);
		
		$op->operations[] = $list;
		return $op;
	}
	
	public static function getCreateOperation($model) {
		$op = new stdClass();
		$op->path = "/" . $model;
		$op->description = 'Operations about ' . $model;
		$op->operations = array();
		
		$list = new stdClass();
		$list->httpMethod = 'POST';
		$list->summary = 'Add new ' . $model;
		$list->nickname = 'create' . ucfirst($model);
		
		$obj = new stdClass();
		$obj->description = ucfirst($model) . ' object to be created';
		$obj->dataType = $model;
		$obj->required = true;
		$obj->allowMultiple = false;
		$obj->paramType = 'body';
		
		$list->parameters = array($obj);
		
		$op->operations[] = $list;
		return $op;
	}
	
	public static function getUpdateOperation($model) {
		$op = new stdClass();
		$op->path = "/" . $model . '/{id}';
		$op->description = 'Operations about ' . $model;
		$op->operations = array();
		
		$list = new stdClass();
		$list->httpMethod = 'PUT';
		$list->summary = 'Update exising ' . $model;
		$list->nickname = 'update' . ucfirst($model);
		
		$id = new stdClass();
		$id->name = 'id';
		$id->description = 'ID of ' . $model . ' that needs to be updated';
		$id->dataType = 'integer';
		$id->required = true;
		$id->allowMultiple = false;
		$id->paramType = 'path';
		
		$obj = new stdClass();
		$obj->description = ucfirst($model) . ' object to be update';
		$obj->dataType = $model;
		$obj->required = true;
		$obj->allowMultiple = false;
		$obj->paramType = 'body';
		
		$list->parameters = array($id, $obj);
		
		$op->operations[] = $list;
		return $op;
	}
	
	public static function getDeleteOperation($model) {
		$op = new stdClass();
		$op->path = "/" . $model . '/{id}';
		$op->description = 'Operations about ' . $model;
		$op->operations = array();
		
		$list = new stdClass();
		$list->httpMethod = 'DELETE';
		$list->summary = 'Delete exising ' . $model;
		$list->nickname = 'delete' . ucfirst($model);
		
		$id = new stdClass();
		$id->name = 'id';
		$id->description = 'ID of ' . $model . ' that needs to be deleted';
		$id->dataType = 'integer';
		$id->required = true;
		$id->allowMultiple = false;
		$id->paramType = 'path';
		
		$list->parameters = array($id);
		
		$op->operations[] = $list;
		return $op;
	}
	
	public static function getServiceOperations($model, $apiResource) {
		
		$services = Service::model()->forModel($model)->findAll();
		
		foreach ($services as $service) {
			$op = new stdClass();
			$op->path = '/' . $model . '/' . $service->service_alias;
			$op->description = 'Operations about ' . $model;
			$op->operations = array();
			
			$list = new stdClass();
			$list->httpMethod = 'GET';
			$list->summary = $service->description;
			$list->nickname = $service->service_alias;
			
			$list->parameters = array();
			
			foreach ($service->getParamArray() as $param => $required) {
				$p = new stdClass();
				$p->name = $param;
				switch ($param) {
					case 'limit':
						$p->dataType = 'integer';
						$p->description = 'Number of records to be fetched';
						break;
					case 'page':
						$p->dataType = 'integer';
						$p->description = 'Page number';
						break;
					default:
						$p->description = $param;
						$p->dataType = 'string';
				}
				$p->required = $required;
				$p->allowMultiple = false;
				$p->paramType = 'query';
				$list->parameters[] = $p;
			}
			$op->operations[] = $list;
			$apiResource->addApi($op);
		}
		
	}
	
	public static function getApiForModel($model) {
		$apiResource = new ApiResource();
		$apiResource->resourcePath = '/' . $model;
		$apiResource->addApi(self::getListOperation($model));
		$apiResource->addApi(ApiOperationFactory::getViewOperation($model));
		$apiResource->addApi(ApiOperationFactory::getCreateOperation($model));
		$apiResource->addApi(ApiOperationFactory::getUpdateOperation($model));
		$apiResource->addApi(ApiOperationFactory::getDeleteOperation($model));
		self::getServiceOperations($model, $apiResource);
		return $apiResource;
	}
}
?>
