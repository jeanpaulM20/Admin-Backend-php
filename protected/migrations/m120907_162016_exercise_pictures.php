<?php
class m120907_162016_exercise_pictures extends CDbMigration
{
    public function up()
    {
    	if (!$this->getDbConnection()->getSchema()->getTable('tbl_exercise_pictures')) {
        	$this->createTable('tbl_exercise_pictures', array(
				'id' => 'pk',
				'label' => 'string NULL',
				'picture' => 'string NULL',
				'description' => 'text NULL',
				'published' => 'boolean NULL',
				'sort' => 'integer NULL DEFAULT \'0\'',
				'exercise_id' => 'integer NOT NULL',
        	), 'ENGINE=InnoDB DEFAULT CHARSET=utf8');
			$this->createIndex('sort', 'tbl_exercise_pictures', 'sort', false);				
			$this->createIndex('exercise_id', 'tbl_exercise_pictures', 'exercise_id', false);				

			
	        }

        
    }
 
    public function down()
    {
    	if ($this->getDbConnection()->getSchema()->getTable('tbl_exercise_pictures')) {
        	$this->dropTable('tbl_exercise_pictures');
        }
    }
}