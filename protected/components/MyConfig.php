<?php
/**
 * MyConfig
 * 
 * @package Yii Extensions
 * @author Twisted1919
 * @copyright 2011
 * @version 1.0
 * @access public
 */
 
class MyConfig extends CApplicationComponent
{
    private $_saveItemsToDatabase=array();
    private $_deleteItemsFromDatabase=array();
    private $_cacheNeedsFlush=false;
    
    protected $_items=array();
    protected $_loadedFiles=array();
    protected $_initialized=false;
    
    public $_cacheId='global_website_config';
    public $_useCache=false;
    public $_cacheTime=0;
    
    public $_tableName='config';
    public $_createTable=false;
    public $_loadDbItems=false;
    public $_serializeValues=true;

    public $_configFile;

    /**
     * MyConfig::init()
     * 
     * @return
     */
    public function init()
    {
        if($this->getCreateTable())
            $this->createTable();
		if($this->getLoadDbItems())
            $this->loadDbItems();
		
        $this->_initialized=true;
        
        Yii::app()->attachEventHandler('onEndRequest', array($this,'whenRequestEnds'));
    }

    /**
     * MyConfig::setItem()
     * 
     * @param mixed $key
     * @param string $value
     * @return
     * 
     * It will set an item to be available during the request.
     */
    public function setItem($key, $value='')
    {
        if(is_array($key))
        {
            foreach($key AS $k=>$v)
                $this->setItem($k, $v);
        }
        else
            $this->_items[$key]=$value;
    }
    
    /**
     * MyConfig::setDbItem()
     * 
     * @param mixed $key
     * @param string $value
     * @return
     * 
     * It will save the item into database.
     * If the item exists, it will be updated.
     */
    public function setDbItem($key, $value='')
    {
        if(is_array($key))
        {
            foreach($key AS $k=>$v)
                $this->setDbItem($k, $v);
        }
        else
        {
            $this->_saveItemsToDatabase[$key]=$value;
            $this->setItem($key, $value);
        } 
    }
    
    /**
     * MyConfig::getItem()
     * 
     * @param mixed $key
     * @return mixed $key
     * 
     * If the items exists it will be returned
     */
    public function getItem($key)
    {
        if(isset($this->_items[$key]))
            return $this->_items[$key];
        return null;
    }
    
    /**
     * MyConfig::deleteItem()
     * 
     * @param mixed $key
     * @return
     * 
     * Delete a temporary item
     */
    public function deleteItem($key)
    {
        if(is_array($key))
        {
            foreach($key AS $k)
                $this->deleteItem($k);
        }
        else
        {
            if(isset($this->_items[$key]))
                unset($this->_items[$key]);    
        }
    }
    
    /**
     * MyConfig::deleteDbItem()
     * 
     * @param mixed $key
     * @return
     * 
     * Delete an item from database directly
     */
    public function deleteDbItem($key)
    {
        if(is_array($key))
        {
            foreach($key AS $k)
                $this->deleteDbItem($k);
        }
        else
        {
            $this->deleteItem($key);
            $this->_deleteItemsFromDatabase[]=$key;
        }
    }
    
    /**
     * MyConfig::deleteItems()
     * 
     * @return
     * 
     * Delete all the temporary items
     */
    public function deleteItems()
    {
        $this->_items=array();
    }
    
    /**
     * MyConfig::deleteDbItems()
     * 
     * @return
     * 
     * Delete all the database items.
     * USE WITH CAUTION!!!
     */
    public function deleteDbItems()
    {
        $this->deleteItems();
        $this->_deleteItemsFromDatabase=array();
        
        $connection=Yii::app()->getDb();
        $command=$connection->createCommand('DELETE FROM '.$this->getTableName().' WHERE 1');
        $command->execute();
        
        $command=$connection->createCommand('ALTER TABLE '.$this->getTableName().' AUTO_INCREMENT=1');
        $command->execute();
        
        if($this->getUseCache())
            Yii::app()->cache->delete($this->getCacheId());
    }
    
    /**
     * MyConfig::loadDbItems()
     * 
     * @return
     * 
     * It will load all the items from the database
     * and store them in the memory and cache if it's the case
     */
    public function loadDbItems()
    {        
        $items=false;
        
        if($this->getUseCache())
            $items=Yii::app()->cache->get($this->getCacheId());

        if(!$items)
        {
            $connection=Yii::app()->getDb();
            $command=$connection->createCommand('SELECT * FROM '.$this->getTableName().' WHERE 1');
            $result=$command->queryAll();
            
            if(empty($result))
                return false;
            
            $items=array();
            foreach($result AS $row)
                $items[$row['key']] = $this->getSerializeValues()?@unserialize($row['value']):$row['value'];

            if($this->getUseCache())
                Yii::app()->cache->add($this->getCacheId(),$items,$this->getCacheTime()); 
        }
        $this->setItem($items);
    }
    
    /**
     * MyConfig::loadConfigFile()
     * 
     * @param mixed $fileArray
     * @param string $keyName 
     * @return
     * 
     * Loads the config items from file(s) within the /protected/config directory.
     * The file(s) needs to return an associative array in key=>value pairs.
     */
    public function loadConfigFile($fileArray,$keyName=null)
    {
        if(empty($fileArray))
            return;
            
        if(is_array($fileArray))
        {
            foreach($fileArray AS $key=>$file)
                $this->loadConfigFile($file, $key); 
        }
        else
        {
            if(file_exists($file=Yii::getPathOfAlias('application.config').DIRECTORY_SEPARATOR.trim($fileArray).'.php'))
            {
                $configArray=include($file);
                if(!empty($keyName) && is_string($keyName))
                    $this->setItem($keyName, $configArray);
                else
                    $this->setItem($configArray);
                clearstatcache();
            }    
        }
        if(!empty($keyName) && is_string($keyName))
            $this->_loadedFiles[]=$keyName;
        return $this;
    }
    
    /**
     * MyConfig::getArray()
     * 
     * @param bool $reset If we should reset the files array after getting the values.
     * @return all the items loaded from files
     * 
     * This method needs to be chained or called after loadConfigFile() in order to return any value.
     */    
    public function getArray($reset=true)
    {
        if(count($this->_loadedFiles)==0)
            return array();
        $return=array();
        foreach($this->_loadedFiles AS $array)
            $return[$array]=$this->getItem($array);
        if($reset)
            $this->_loadedFiles=array();
        return $return;
    }
    
    /**
     * MyConfig::toArray()
     * 
     * @return all the items stored in the memory
     */
    public function toArray()
    {
        return $this->_items;
    }
    
    /**
     * MyConfig::fromConfigToDb()
     * 
     * @param mixed $fileName
     * @param string $fileKey
     * @return 
     * 
     * This method allows you to import the content of a file into database.
     * Please read carefully the description below.
     * 
     * If the fileName is array(), the correct way of formatting it is
     * array('config-item-name'=>'config-file-to-load');
     * Accessing component->getItem('config-item-name') will return the file array with key=>value pairs
     * 
     * If the fileName is a string then the key=>value array returned by 
     * the file will be loaded into database.
     * In this case you will access directly the array keys returned by the file 
     * like component->getItem('a-key-from-file');
     * 
     * If fileName is a string, and also fileKey is a string, 
     * then the fileKey will be saved into database, having the values of fileName
     * In this case, you will access like component->getItem('fileKey'); which returns an array.
     * 
     * Of course, the file needs to exists in order to make the import.
     * 
     * Personal suggestion would be to load something like:
     * 
     * MyConfig::fromConfigToDb(array('authorizeNet'=>authorizeNetConfigFile));
     * OR
     * MyConfig::fromConfigToDb(authorizeNetConfigFile, authorizeNet);
     * 
     * Then get the contents of the file:
     * $authorizeConfig=MyConfig::getItem('authorizeNet');
     * 
     * If you need to update:
     * $authorizeConfig['custom-key-1']='New value 1';
     * $authorizeConfig['custom-key-2']='New value 2';
     * MyConfig::setDbItem(array('authorizeNet'=>$authorizeConfig));
     * OR just update the file and reload it again using  MyConfig::fromConfigToDb
     * And you are done.
     */
    public function fromConfigToDb($fileName, $fileKey='')
    {
        if(is_array($fileName))
        {
            foreach($fileName AS $key=>$value)
                $this->fromConfigToDb($value, $key);
        }
        else
        {
            if(!empty($fileKey))
            {
                $this->loadConfigFile($fileName, $fileKey);
                $this->setDbItem($fileKey, $this->getItem($fileKey));
            }
            else
            {
                $toLoad=$this->loadConfigFile(array('temp'=>$fileName))->getArray();
                foreach($toLoad['temp'] AS $k=>$v)
                    $this->setDbItem($k, $v);
            }
        }
    }
    
    /**
     * MyConfig::setTableName()
     * 
     * @param string $str The table name
     */    
    public function setTableName($str)
    {
        $this->_tableName=$str;
    }
    
    /**
     * MyConfig::getTableName()
     * 
     * @return string config table name
     */ 
    public function getTableName()
    {
        return $this->_tableName;
    }
    
    /**
     * MyConfig::setCreateTable()
     * 
     * @param bool $bool
     * 
     * Whether the table name should be created or not
     */ 
    public function setCreateTable($bool)
    {
        $this->_createTable=(bool)$bool;
    }
    
    /**
     * MyConfig::getCreateTable()
     * 
     * @return bool
     * 
     * Whether the table name should be created or not
     */ 
    public function getCreateTable()
    {
        return $this->_createTable;
    }
    
    /**
     * MyConfig::setLoadDbItems()
     * 
     * @param bool $bool
     * 
     * Whether the database items should be loaded at init
     */ 
    public function setLoadDbItems($bool)
    {
        $this->_loadDbItems=(bool)$bool;
    }
    
    /**
     * MyConfig::getLoadDbItems()
     * 
     * @return bool
     * 
     * Whether the database items should be loaded at init
     */ 
    public function getLoadDbItems()
    {
        return $this->_loadDbItems;
    }
    
    /**
     * MyConfig::setCacheTime()
     * 
     * @param int $int
     * 
     * Set the time in seconds to keep the cached database items
     */
    public function setCacheTime($int)
    {
        $this->_cacheTime=(int)$int>0?$int:0;
    }
    
    /**
     * MyConfig::getCacheTime()
     * 
     * @return int 
     * 
     * Get the time in seconds to keep the cached database items
     */
    public function getCacheTime()
    {
        return $this->_cacheTime;
    }
    
    /**
     * MyConfig::setUseCache()
     * 
     * @param bool $bool 
     * 
     * Whether the component should cache the database items
     * Note that, you need to have a cache component active in order to use this feature
     */
    public function setUseCache($bool)
    {
        $this->_useCache=(bool)$bool;
    }
    
    /**
     * MyConfig::getUseCache()
     * 
     * @return bool 
     * 
     * Whether the component is caching  the database items
     */
    public function getUseCache()
    {
        return $this->_useCache;
    }
    
    /**
     * MyConfig::setCacheId()
     * 
     * @param string $str 
     * 
     * Set the id of the cache file if the caching is enabled
     */
    public function setCacheId($str)
    {
        $this->_cacheId=!empty($str)?md5($str):md5($this->_cacheId);
    }
    
    /**
     * MyConfig::getCacheId()
     * 
     * @return bool 
     * 
     * Get the id of the cache file
     */
    public function getCacheId()
    {
        return $this->_cacheId;
    }
    
    /**
     * MyConfig::setSerializeValues()
     * 
     * @param bool $bool 
     * 
     * Whether the items that are saved to database should be serialized.
     * Normally, you would set this to true, so that you keep the type of the variables.
     */
    public function setSerializeValues($bool)
    {
        $this->_serializeValues=(bool)$bool;
    }
    
    /**
     * MyConfig::getSerializeValues()
     * 
     * @return bool  
     * 
     * Whether the items that are saved to database should be serialized.
     */
    public function getSerializeValues()
    {
        return $this->_serializeValues;
    }
    
    /**
     * MyConfig::setConfigFile()
     * 
     * @param mixed $mixed 
     * 
     * Whether the component should load additional config file(s)
     * You can pass a string having the file name, or
     * multiple files separated by a comma, or an array.
     * Note, in each of the cases, don't include the .php extension
     */
    public function setConfigFile($mixed)
    {
        $this->_configFile=$mixed;
        if(is_string($this->_configFile) && strpos($this->_configFile,',')!==false)
            $this->_configFile=explode(',',$this->_configFile);
        $this->loadConfigFile($this->_configFile);
    }
    
    /**
     * MyConfig::getConfigFile()
     * 
     * @return mixed  
     * 
     * Returns the config files(s) in a string/array format
     */
    public function getConfigFile()
    {
        return $this->_configFile;
    }

    
    /**
     * MyConfig::setIsInitialized()
     * 
     * @param bool $bool
     * 
     * Whether the component should be initialized
     */    
    public function setIsInitialized($bool)
    {
        $this->_initialized=(bool)$bool;
    }
    
    /**
     * MyConfig::getIsInitialized()
     * 
     * @return bool
     * 
     * Whether the component is initialized
     */  
    public function getIsInitialized()
    {
        return $this->_initialized;
    }   
    
    /**
     * MyConfig::createTable()
     * 
     * @return
     * 
     * If the database table doesn't exists, it will create it
     */
    private function createTable()
    {
        $sql='CREATE TABLE IF NOT EXISTS `'.$this->getTableName().'` (
              `id` int(11) NOT NULL AUTO_INCREMENT,
              `updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
              `key` varchar(255) NOT NULL,
              `value` text NOT NULL,
              PRIMARY KEY (`id`),
              KEY `key` (`key`)
            ) ENGINE=InnoDB  DEFAULT CHARSET=utf8 AUTO_INCREMENT=1 ;';
        
        $connection=Yii::app()->getDb();
        $command=$connection->createCommand($sql);
        $command->execute();
    }
    
    /**
     * MyConfig::addDbItem()
     * 
     * @param mixed $key
     * @param mixed $value
     * @return
     * 
     * Performs the logic for add/update database item
     */
    private function addDbItem($key, $value)
    {
        $connection=Yii::app()->getDb();
        $command=$connection->createCommand('SELECT * FROM '.$this->getTableName().' WHERE `key`=:key LIMIT 1');
        $command->bindParam(':key',$key,PDO::PARAM_STR);
        $result=$command->queryRow();
        $_value=$this->getSerializeValues()?serialize($value):$value;
        
        if(!empty($result))
        {
            $command=$connection->createCommand('UPDATE '.$this->getTableName().' SET `value`=:value WHERE `key`=:key');
            $command->bindParam(':value',$_value,PDO::PARAM_STR);
            $command->bindParam(':key',$key,PDO::PARAM_STR);
            $command->execute();
        }
        else
        {
            $command=$connection->createCommand('INSERT INTO '.$this->getTableName().' (`key`,`value`) VALUES(:key,:value)');
            $command->bindParam(':key',$key,PDO::PARAM_STR);
            $command->bindParam(':value',$_value,PDO::PARAM_STR);
            $command->execute();
        }
    }
    
    /**
     * MyConfig::whenRequestEnds()
     *
     * @return
     * 
     * Called at the end of request to do the heavy lifting.
     */
    protected function whenRequestEnds()
    {
        if(count($this->_saveItemsToDatabase)>0)
        {
            $this->_cacheNeedsFlush=true;
            
            foreach($this->_saveItemsToDatabase AS $k=>$v)
                $this->addDbItem($k, $v);
        }
        if(($cnt=count($this->_deleteItemsFromDatabase))>0)
        {
            $this->_cacheNeedsFlush=true;
            
            $inQuery = implode(',', array_fill(0, $cnt, '?'));
            $connection=Yii::app()->getDb();
            $command=$connection->createCommand('DELETE FROM '.$this->getTableName().' WHERE `key` IN ('.$inQuery.')');
            foreach($this->_deleteItemsFromDatabase AS $k=>$v)
                $command->bindValue(($k+1), $v);
            $command->execute();
        }
        if($this->_cacheNeedsFlush && $this->getUseCache())
            Yii::app()->cache->delete($this->getCacheId());
    } 
    


}